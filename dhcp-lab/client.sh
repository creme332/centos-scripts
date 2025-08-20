#!/bin/bash

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
for key in "${cfg[@]/%/}"; do
    if grep -q "^$key=" "$IFCFG_FILE" 2>/dev/null; then
        sed -i "s/^$key=.*/$key=${cfg[$key]}/" "$IFCFG_FILE"
    else
        echo "$key=${cfg[$key]}" >> "$IFCFG_FILE"
    fi
done

echo "DHCP client configuration complete for interface: $PRIMARY_IF"
echo "Verify with: ifconfig $PRIMARY_IF or 'nmcli device status'"
