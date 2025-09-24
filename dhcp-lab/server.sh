#!/bin/bash

#------------------------------------------------------------------------------------
# Script Name: Setup DHCP Server on CentOS 7.9
# Description: Installs and configures a DHCP server on a 
#              CentOS 7.9 machine. Handles static IP 
#              configuration, interface backup, DHCPDARGS 
#              setup, dhcpd.conf creation, and validation.
#              All parameters are required - no defaults.
# Usage: bash server.sh SERVER_IP RANGE_START RANGE_END NETMASK GATEWAY
# Version: 1.0
# Author: creme332
#------------------------------------------------------------------------------------
# Requirements:
# - CentOS 7.9.2009 with root privileges
# - Internet connectivity for package installation and updates
# - VMware or physical machine (not WSL2) with at least one network interface
# - All 5 parameters must be provided (no defaults)
#------------------------------------------------------------------------------------
# Parameters:
# SERVER_IP   : Static IP for DHCP server (must be outside DHCP range)
# RANGE_START : First IP address in the DHCP pool
# RANGE_END   : Last IP address in the DHCP pool  
# NETMASK     : Subnet mask for the network
# GATEWAY     : Default gateway IP
# Note: SUBNET is automatically calculated using SERVER_IP & NETMASK
#------------------------------------------------------------------------------------

set -euo pipefail

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

DATE_SUFFIX=$(date +%F-%T)

# Function to display usage
usage() {
    echo "Usage: $0 SERVER_IP RANGE_START RANGE_END NETMASK GATEWAY"
    echo ""
    echo "All parameters are REQUIRED:"
    echo "  SERVER_IP   : Static IP for DHCP server"
    echo "  RANGE_START : Start of DHCP range"
    echo "  RANGE_END   : End of DHCP range"
    echo "  NETMASK     : Subnet mask"
    echo "  GATEWAY     : Gateway IP"
    echo ""
    echo "Note: SUBNET is automatically calculated using SERVER_IP & NETMASK"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.10 192.168.1.100 192.168.1.200 255.255.255.0 192.168.1.1"
    echo "  $0 125.150.175.99 125.150.175.100 125.150.175.125 255.248.0.0 175.200.225.1"
    echo "  $0 10.0.0.10 10.0.0.50 10.0.0.100 255.255.255.0 10.0.0.1"
    exit 1
}

# Check for help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
fi

# Check if all required parameters are provided
if [ $# -ne 5 ]; then
    echo "Error: All 5 parameters are required!"
    echo "Provided: $# parameters"
    echo ""
    usage
fi

# Parse command line parameters (all required, no defaults)
STATIC_IP="$1"
DHCP_RANGE_START="$2"
DHCP_RANGE_END="$3"
NETMASK="$4"
GATEWAY="$5"

# Function to calculate subnet using bitwise AND
calculate_subnet() {
    local ip="$1"
    local mask="$2"
    
    # Convert IP to array of octets
    IFS='.' read -ra ip_octets <<< "$ip"
    IFS='.' read -ra mask_octets <<< "$mask"
    
    # Calculate subnet using bitwise AND for each octet
    local subnet_octets=()
    for i in {0..3}; do
        subnet_octets[i]=$((${ip_octets[i]} & ${mask_octets[i]}))
    done
    
    # Join octets with dots
    local subnet="${subnet_octets[0]}.${subnet_octets[1]}.${subnet_octets[2]}.${subnet_octets[3]}"
    echo "$subnet"
}

# Calculate subnet automatically
SUBNET=$(calculate_subnet "$STATIC_IP" "$NETMASK")

# Calculate broadcast address based on netmask
calculate_broadcast() {
    local subnet="$1"
    local mask="$2"
    
    # Convert to arrays
    IFS='.' read -ra subnet_octets <<< "$subnet"
    IFS='.' read -ra mask_octets <<< "$mask"
    
    # Calculate broadcast using bitwise OR with inverted mask
    local broadcast_octets=()
    for i in {0..3}; do
        local inverted_mask=$((255 - ${mask_octets[i]}))
        broadcast_octets[i]=$((${subnet_octets[i]} | inverted_mask))
    done
    
    # Join octets with dots
    local broadcast="${broadcast_octets[0]}.${broadcast_octets[1]}.${broadcast_octets[2]}.${broadcast_octets[3]}"
    echo "$broadcast"
}

# Calculate broadcast address automatically
BROADCAST=$(calculate_broadcast "$SUBNET" "$NETMASK")

echo "DHCP Configuration:"
echo "  Server IP: $STATIC_IP"
echo "  Netmask: $NETMASK"
echo "  Calculated Subnet: $SUBNET"
echo "  Calculated Broadcast: $BROADCAST"
echo "  Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
echo "  Gateway: $GATEWAY"
echo ""

# Validate IP addresses (basic validation)
validate_ip() {
    local ip=$1
    local name=$2
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Error: Invalid IP address format for $name: $ip"
        exit 1
    fi
    
    # Check each octet is 0-255
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if ((octet < 0 || octet > 255)); then
            echo "Error: Invalid IP address octet for $name: $ip (octet: $octet)"
            exit 1
        fi
    done
}

# Validate netmask format
validate_netmask() {
    local mask=$1
    validate_ip "$mask" "NETMASK"
    
    # Additional netmask validation - check it's a valid subnet mask
    IFS='.' read -ra octets <<< "$mask"
    local binary=""
    for octet in "${octets[@]}"; do
        binary+=$(printf "%08d" $(bc <<< "obase=2;$octet"))
    done
    
    # Check that all 1s come before all 0s (valid subnet mask pattern)
    if [[ ! $binary =~ ^1*0*$ ]]; then
        echo "Error: Invalid subnet mask format: $mask"
        echo "Subnet mask must have contiguous 1s followed by contiguous 0s"
        exit 1
    fi
}

validate_ip "$STATIC_IP" "SERVER_IP"
validate_ip "$DHCP_RANGE_START" "RANGE_START"
validate_ip "$DHCP_RANGE_END" "RANGE_END"
validate_netmask "$NETMASK"
validate_ip "$GATEWAY" "GATEWAY"

# Additional logical validation
echo "Performing logical validation..."

# Check if server IP is in the same subnet as the calculated subnet
SERVER_SUBNET=$(calculate_subnet "$STATIC_IP" "$NETMASK")
if [[ "$SERVER_SUBNET" != "$SUBNET" ]]; then
    echo "Error: Server IP $STATIC_IP is not in the calculated subnet $SUBNET"
    echo "Server would be in subnet: $SERVER_SUBNET"
    exit 1
fi

# Check if DHCP range is within the same subnet
RANGE_START_SUBNET=$(calculate_subnet "$DHCP_RANGE_START" "$NETMASK")
RANGE_END_SUBNET=$(calculate_subnet "$DHCP_RANGE_END" "$NETMASK")

if [[ "$RANGE_START_SUBNET" != "$SUBNET" ]]; then
    echo "Error: DHCP range start $DHCP_RANGE_START is not in subnet $SUBNET"
    exit 1
fi

if [[ "$RANGE_END_SUBNET" != "$SUBNET" ]]; then
    echo "Error: DHCP range end $DHCP_RANGE_END is not in subnet $SUBNET"
    exit 1
fi

# Check if server IP conflicts with DHCP range
IFS='.' read -ra server_octets <<< "$STATIC_IP"
IFS='.' read -ra start_octets <<< "$DHCP_RANGE_START"
IFS='.' read -ra end_octets <<< "$DHCP_RANGE_END"

server_num=$((${server_octets[0]}*16777216 + ${server_octets[1]}*65536 + ${server_octets[2]}*256 + ${server_octets[3]}))
start_num=$((${start_octets[0]}*16777216 + ${start_octets[1]}*65536 + ${start_octets[2]}*256 + ${start_octets[3]}))
end_num=$((${end_octets[0]}*16777216 + ${end_octets[1]}*65536 + ${end_octets[2]}*256 + ${end_octets[3]}))

if (( server_num >= start_num && server_num <= end_num )); then
    echo "Warning: Server IP $STATIC_IP is within DHCP range $DHCP_RANGE_START - $DHCP_RANGE_END"
    echo "This may cause IP conflicts. Consider using an IP outside the DHCP range."
fi

echo "Validation complete."
echo ""

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

# Step 5: Validate DHCP configuration (don't enable or start service)
echo "Validating DHCP configuration..."
if dhcpd -t -cf /etc/dhcp/dhcpd.conf 2>/dev/null; then
    echo "DHCP configuration is valid."
else
    echo "Error: DHCP configuration validation failed!"
    dhcpd -t -cf /etc/dhcp/dhcpd.conf
    exit 1
fi

echo "DHCP Server setup complete."
echo ""
echo "=== Configuration Summary ==="
echo "  Server IP: $STATIC_IP"
echo "  DHCP Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
echo "  Gateway: $GATEWAY"
echo "  Subnet: $SUBNET/$NETMASK"
echo "  Broadcast: $BROADCAST"
echo ""
