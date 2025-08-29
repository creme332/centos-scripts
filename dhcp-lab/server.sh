#!/bin/bash

#------------------------------------------------------------------------------------
# Script Name: Setup DHCP Server on CentOS 7.9
# Description: Installs and configures a DHCP server on a 
#              CentOS 7.9 machine. Handles static IP 
#              configuration, interface backup, DHCPDARGS 
#              setup, dhcpd.conf creation, service enablement, 
#              and verification of service status.
# Usage: Run the script as root using bash server.sh
# Version: 0.0
# Author: creme332
#------------------------------------------------------------------------------------
# Requirements:
# - CentOS 7.9.2009 with root privileges
# - Internet connectivity for package installation and updates
# - VMware or physical machine (not WSL2) with at least one network interface
#------------------------------------------------------------------------------------

set -euo pipefail

DATE_SUFFIX=$(date +%F-%T)

# Function to create backups
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.backup.${DATE_SUFFIX}"
        cp -p "$file" "$backup"
        echo "Backup of $file saved as $backup"
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
backup_file "$IFCFG_FILE"

STATIC_IP="200.100.50.10"
NETMASK="255.255.255.0"
GATEWAY="$STATIC_IP"
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
backup_file "$DHCPD_FILE"

if grep -q "^DHCPDARGS=" "$DHCPD_FILE"; then
    sed -i "s/^DHCPDARGS=.*/DHCPDARGS=$PRIMARY_IF/" "$DHCPD_FILE"
else
    echo "DHCPDARGS=$PRIMARY_IF" >> "$DHCPD_FILE"
fi
echo "$DHCPD_FILE configured with DHCPDARGS=$PRIMARY_IF"

# Step 4: Configure /etc/dhcp/dhcpd.conf
DOMAIN_NAME=$(hostname -d)
if [ -z "$DOMAIN_NAME" ]; then
    DOMAIN_NAME="localdomain"
fi

DHCP_CONF="/etc/dhcp/dhcpd.conf"
backup_file "$DHCP_CONF"

cat > "$DHCP_CONF" <<EOF
option domain-name "$DOMAIN_NAME";
option domain-name-servers $STATIC_IP, 208.67.222.222;
default-lease-time 600;
max-lease-time 7200;
log-facility local7;

subnet 200.100.50.0 netmask 255.255.255.0 {
    range 200.100.50.1 200.100.50.25;
    option broadcast-address 200.100.50.255;
    option routers $STATIC_IP;
}
EOF

echo "$DHCP_CONF configured with subnet and lease settings."

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
echo "Check client IP allocation using ifconfig on the client."
