#!/bin/bash

#--------------------------------------------------------------
# Script Name: Setup DHCP Client on CentOS 7.9
# Description: Configures a CentOS 7.9 machine to obtain its IP
#              address dynamically via DHCP. Handles interface 
#              detection, backup of existing configuration files, 
#              and updates network scripts.
# Usage: Run the script as root using bash dhcp-client.sh
# Version: 0.0
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - CentOS 7.9.2009 with root privileges
# - Internet connectivity to test reachability
# - VMware or physical machine (not WSL2) with at least one network interface
#--------------------------------------------------------------

set -euo pipefail

DATE_SUFFIX=$(date +%F-%T)

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

# Install packages (These packages are typically already installed)
yum install -y dhclient net-tools NetworkManager
systemctl enable NetworkManager
systemctl start NetworkManager

# Detect primary NIC using ifconfig, remove trailing colon
PRIMARY_IF=$(ifconfig -a | sed 's/[ \t].*//;/^$/d' | grep -v lo | head -n 1 | tr -d ':')

if [ -z "$PRIMARY_IF" ]; then
    echo "No valid network interface detected."
    exit 1
fi
echo "Detected primary network interface: $PRIMARY_IF"

NETWORK_FILE="/etc/sysconfig/network"
IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-${PRIMARY_IF}"

# Step 1: Configure /etc/sysconfig/network
backup_file "$NETWORK_FILE"
if grep -q "^NETWORKING=" "$NETWORK_FILE"; then
    sed -i 's/^NETWORKING=.*/NETWORKING=yes/' "$NETWORK_FILE"
else
    echo "NETWORKING=yes" >> "$NETWORK_FILE"
fi

# Step 2: Configure interface
backup_file "$IFCFG_FILE"
declare -A cfg
cfg=( ["DEVICE"]="$PRIMARY_IF" ["BOOTPROTO"]="dhcp" ["TYPE"]="Ethernet" ["ONBOOT"]="yes" )

touch "$IFCFG_FILE"
for key in "${!cfg[@]}"; do
    if grep -q "^$key=" "$IFCFG_FILE" 2>/dev/null; then
        sed -i "s/^$key=.*/$key=${cfg[$key]}/" "$IFCFG_FILE"
    else
        echo "$key=${cfg[$key]}" >> "$IFCFG_FILE"
    fi
done

# Restart network to apply DHCP configuration
systemctl restart network

# Verify IP assignment
echo "Verifying DHCP IP assignment on $PRIMARY_IF..."
for i in {1..5}; do
    IP_ASSIGNED=$(ip addr show "$PRIMARY_IF" | awk '/inet / {print $2}' | cut -d/ -f1)
    if [ -n "$IP_ASSIGNED" ]; then
        echo "DHCP client received IP: $IP_ASSIGNED on interface $PRIMARY_IF"
        break
    else
        echo "Waiting for IP assignment..."
        sleep 1
    fi
done

if [ -z "$IP_ASSIGNED" ]; then
    echo "Failed to obtain IP via DHCP on $PRIMARY_IF"
    exit 1
fi

echo "DHCP client configuration complete."
