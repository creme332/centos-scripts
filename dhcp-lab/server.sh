#!/bin/bash

# DHCP Server Configuration Script for CentOS 7.9

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

# Step 0: Install DHCP server and client
echo "Installing DHCP package..."
yum install -y dhcp

# Step 1: Detect primary NIC using ifconfig (non-loopback)
PRIMARY_IF=$(ifconfig -a | sed 's/[ \t].*//;/^$/d' | grep -v lo | head -n 1 | tr -d ':')
if [ -z "$PRIMARY_IF" ]; then
    echo "No valid network interface detected."
    exit 1
fi
echo "Detected primary network interface: $PRIMARY_IF"

# Step 2: Configure static IP for the server interface
IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-${PRIMARY_IF}"
backup_file "$IFCFG_FILE"

STATIC_IP="200.100.50.10"
NETMASK="255.255.255.0"
GATEWAY="$STATIC_IP"
HWADDR=$(ifconfig "$PRIMARY_IF" | grep -i ether | awk '{print $2}')

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

# Step 3: Configure DHCPDARGS in /etc/sysconfig/dhcpd
DHCPD_FILE="/etc/sysconfig/dhcpd"
backup_file "$DHCPD_FILE"

if grep -q "^DHCPDARGS=" "$DHCPD_FILE"; then
    sed -i "s/^DHCPDARGS=.*/DHCPDARGS=$PRIMARY_IF/" "$DHCPD_FILE"
else
    echo "DHCPDARGS=$PRIMARY_IF" >> "$DHCPD_FILE"
fi
echo "$DHCPD_FILE configured with DHCPDARGS=$PRIMARY_IF"

# Determine the system domain name dynamically, fallback to 'localdomain'
DOMAIN_NAME=$(hostname -d)
if [ -z "$DOMAIN_NAME" ]; then
    DOMAIN_NAME="localdomain"
fi

# Step 4: Configure /etc/dhcp/dhcpd.conf
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
systemctl status dhcpd --no-pager

echo "DHCP Server setup complete."
echo "Check client IP allocation using ifconfig on the client."
