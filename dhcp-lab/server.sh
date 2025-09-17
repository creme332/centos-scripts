#!/bin/bash

#------------------------------------------------------------------------------------
# Script Name: Setup DHCP Server on CentOS 7.9
# Description: Installs and configures a DHCP server on a 
#              CentOS 7.9 machine. Handles static IP 
#              configuration, interface backup, DHCPDARGS 
#              setup, dhcpd.conf creation, service enablement, 
#              and verification of service status.
# Usage: Run the script as root using bash server.sh
# Version: 0.1
# Author: creme332
#------------------------------------------------------------------------------------
# Requirements:
# - CentOS 7.9.2009 with root privileges
# - Internet connectivity for package installation and updates
# - VMware or physical machine (not WSL2) with at least one network interface
#------------------------------------------------------------------------------------

set -euo pipefail

DATE_SUFFIX=$(date +%F-%T)

# Function to display usage
usage() {
    echo "Usage: $0 [SERVER_IP] [RANGE_START] [RANGE_END] [SUBNET] [NETMASK] [GATEWAY]"
    echo ""
    echo "Parameters (all optional, defaults shown):"
    echo "  SERVER_IP   : Static IP for DHCP server (default: 200.100.50.10)"
    echo "  RANGE_START : Start of DHCP range (default: 200.100.50.1)"
    echo "  RANGE_END   : End of DHCP range (default: 200.100.50.25)"
    echo "  SUBNET      : Network subnet (default: 200.100.50.0)"
    echo "  NETMASK     : Subnet mask (default: 255.255.255.0)"
    echo "  GATEWAY     : Gateway IP (default: same as SERVER_IP)"
    echo ""
    echo "Examples:"
    echo "  $0                                           # Use all defaults"
    echo "  $0 192.168.1.10                            # Custom server IP only"
    echo "  $0 192.168.1.10 192.168.1.100 192.168.1.200 192.168.1.0"
    echo "  $0 10.0.0.1 10.0.0.50 10.0.0.100 10.0.0.0 255.255.255.0 10.0.0.1"
    exit 1
}

# Check for help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
fi

# Parse command line parameters with defaults
STATIC_IP="${1:-200.100.50.10}"
DHCP_RANGE_START="${2:-200.100.50.1}"
DHCP_RANGE_END="${3:-200.100.50.25}"
SUBNET="${4:-200.100.50.0}"
NETMASK="${5:-255.255.255.0}"
GATEWAY="${6:-$STATIC_IP}"

# Calculate broadcast address if not provided (simple calculation for /24)
if [[ "$NETMASK" == "255.255.255.0" ]]; then
    BROADCAST="${SUBNET%.*}.255"
else
    # For non-/24 networks, user should specify or we use a default
    BROADCAST="${SUBNET%.*}.255"
fi

echo "DHCP Configuration:"
echo "  Server IP: $STATIC_IP"
echo "  Subnet: $SUBNET/$NETMASK"
echo "  Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
echo "  Gateway: $GATEWAY"
echo "  Broadcast: $BROADCAST"
echo ""

# Validate IP addresses (basic validation)
validate_ip() {
    local ip=$1
    local name=$2
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Error: Invalid IP address format for $name: $ip"
        exit 1
    fi
}

validate_ip "$STATIC_IP" "SERVER_IP"
validate_ip "$DHCP_RANGE_START" "RANGE_START"
validate_ip "$DHCP_RANGE_END" "RANGE_END"
validate_ip "$SUBNET" "SUBNET"
validate_ip "$GATEWAY" "GATEWAY"

# Function to create backups
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.backup.${DATE_SUFFIX}"
        cp -p "$file" "$backup"
        echo "Backup of $file saved as $backup"
    else
        echo "Warning: $file does not exist, cannot create backup"
        return 1
    fi
}

# Check if YUM is working
if yum repolist enabled >/dev/null 2>&1 && yum makecache fast >/dev/null 2>&1; then
    echo "YUM OK"
else
    echo "YUM is not setup properly. Run yum.sh. Exiting."
    exit 1
fi

# Root check
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# Internet check
if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo "Internet is available."
else
    echo "No internet connection. Exiting."
    exit 1
fi

# Step 0: Install DHCP server
echo "Installing DHCP package..."
yum install -y dhcp net-tools

# Step 1: Detect primary NIC using ip (non-loopback)
PRIMARY_IF=$(ip -o link show | awk -F': ' '$2 != "lo"{print $2}' | head -n1)
if [ -z "$PRIMARY_IF" ]; then
    echo "No valid network interface detected."
    exit 1
fi
echo "Detected primary network interface: $PRIMARY_IF"

# Step 2: Configure static IP
IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-${PRIMARY_IF}"
if ! backup_file "$IFCFG_FILE"; then
    echo "Critical: Cannot backup network interface file. Exiting."
    exit 1
fi

HWADDR=$(ip link show "$PRIMARY_IF" | awk '/ether/ {print $2}')

declare -A cfg
cfg=( 
    ["DEVICE"]="$PRIMARY_IF" 
    ["HWADDR"]="$HWADDR" 
    ["NM_CONTROLLED"]="yes"
    ["ONBOOT"]="yes"
    ["BOOTPROTO"]="none"
    ["IPADDR"]="$STATIC_IP"
    ["NETMASK"]="$NETMASK"
    ["GATEWAY"]="$GATEWAY"
)

touch "$IFCFG_FILE"
for key in "${!cfg[@]}"; do
    if grep -q "^$key=" "$IFCFG_FILE" 2>/dev/null; then
        sed -i "s/^$key=.*/$key=${cfg[$key]}/" "$IFCFG_FILE"
    else
        echo "$key=${cfg[$key]}" >> "$IFCFG_FILE"
    fi
done
echo "$IFCFG_FILE configured with static IP $STATIC_IP"

# Restart network and verify IP applied
systemctl restart network

if ip addr show "$PRIMARY_IF" | grep -q "$STATIC_IP"; then
    echo "Network interface $PRIMARY_IF is up with IP $STATIC_IP"
else
    echo "Failed to apply static IP to $PRIMARY_IF. Exiting."
    exit 1
fi

# Step 3: Configure DHCPDARGS
DHCPD_FILE="/etc/sysconfig/dhcpd"
if ! backup_file "$DHCPD_FILE"; then
    echo "Critical: Cannot backup DHCP sysconfig file. Exiting."
    exit 1
fi

if grep -q "^DHCPDARGS=" "$DHCPD_FILE"; then
    sed -i "s/^DHCPDARGS=.*/DHCPDARGS=$PRIMARY_IF/" "$DHCPD_FILE"
else
    echo "DHCPDARGS=$PRIMARY_IF" >> "$DHCPD_FILE"
fi
echo "$DHCPD_FILE configured with DHCPDARGS=$PRIMARY_IF"

# Step 4: Configure /etc/dhcp/dhcpd.conf (hardcoded entire file)
DOMAIN_NAME=$(hostname -d)
if [ -z "$DOMAIN_NAME" ]; then
    DOMAIN_NAME="localdomain"
fi

DHCP_CONF="/etc/dhcp/dhcpd.conf"
backup_file "$DHCP_CONF"  # This might not exist after fresh install, that's ok

cat > "$DHCP_CONF" <<EOF
# DHCP Server Configuration
# Generated by server.sh on $(date)

option domain-name "$DOMAIN_NAME";
option domain-name-servers $STATIC_IP, 208.67.222.222;
default-lease-time 600;
max-lease-time 7200;
log-facility local7;

# Subnet declaration
subnet $SUBNET netmask $NETMASK {
    range $DHCP_RANGE_START $DHCP_RANGE_END;
    option broadcast-address $BROADCAST;
    option routers $GATEWAY;
}
EOF

echo "$DHCP_CONF configured with subnet $SUBNET and range $DHCP_RANGE_START-$DHCP_RANGE_END"

# Step 5: Start DHCP service
echo "Starting DHCP service..."
systemctl enable dhcpd
systemctl restart dhcpd

# Wait up to 5 seconds for service to become active
for i in {1..5}; do
    if systemctl is-active --quiet dhcpd; then
        echo "DHCP service started successfully."
        break
    else
        sleep 1
    fi
done

if ! systemctl is-active --quiet dhcpd; then
    echo "Failed to start DHCP service."
    systemctl status dhcpd --no-pager
    exit 1
fi

echo "DHCP Server setup complete."
echo "Configuration Summary:"
echo "  Server IP: $STATIC_IP"
echo "  DHCP Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
echo "  Gateway: $GATEWAY"
echo "Check client IP allocation using ifconfig on the client."