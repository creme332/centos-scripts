#!/bin/bash

#--------------------------------------------------------------
# Script Name: Uninstall DHCP Client on CentOS 7.9
# Description: Restores original network configuration from 
#              backups and removes DHCP client configuration.
#              Completely resets all DHCP client settings.
# Usage: Run the script as root using bash uninstall-client.sh
# Version: 0.0
# Author: creme332
#--------------------------------------------------------------

set -euo pipefail

# Root check
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

echo "Starting DHCP Client uninstallation..."

# Step 1: Detect primary interface
PRIMARY_IF=$(ip -o link show | awk -F': ' '$2 != "lo"{print $2}' | head -n1)
if [ -z "$PRIMARY_IF" ]; then
    echo "No valid network interface detected."
    exit 1
fi
echo "Detected primary network interface: $PRIMARY_IF"

# Step 2: Restore network configuration
NETWORK_FILE="/etc/sysconfig/network"
BACKUP_NETWORK=$(find /etc/sysconfig/ -name "network.backup.*" 2>/dev/null | sort -r | head -n1)

if [ -n "$BACKUP_NETWORK" ] && [ -f "$BACKUP_NETWORK" ]; then
    echo "Restoring network configuration from $BACKUP_NETWORK"
    cp "$BACKUP_NETWORK" "$NETWORK_FILE"
else
    echo "No backup found for network configuration. Using default..."
    cat > "$NETWORK_FILE" <<EOF
NETWORKING=yes
HOSTNAME=localhost.localdomain
EOF
fi

# Step 3: Restore interface configuration
IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-${PRIMARY_IF}"
BACKUP_IFCFG=$(find /etc/sysconfig/network-scripts/ -name "ifcfg-${PRIMARY_IF}.backup.*" 2>/dev/null | sort -r | head -n1)

if [ -n "$BACKUP_IFCFG" ] && [ -f "$BACKUP_IFCFG" ]; then
    echo "Restoring interface configuration from $BACKUP_IFCFG"
    cp "$BACKUP_IFCFG" "$IFCFG_FILE"
    echo "Interface configuration restored"
else
    echo "No backup found for interface configuration."
    echo "You may need to manually configure network settings."
    
    # Provide a basic static IP template as fallback
    read -p "Would you like to set a static IP? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter IP address (e.g., 192.168.1.100): " STATIC_IP
        read -p "Enter netmask (e.g., 255.255.255.0): " NETMASK
        read -p "Enter gateway (e.g., 192.168.1.1): " GATEWAY
        
        HWADDR=$(ip link show "$PRIMARY_IF" | awk '/ether/ {print $2}')
        
        cat > "$IFCFG_FILE" <<EOF
DEVICE=$PRIMARY_IF
HWADDR=$HWADDR
ONBOOT=yes
BOOTPROTO=none
IPADDR=$STATIC_IP
NETMASK=$NETMASK
GATEWAY=$GATEWAY
EOF
        echo "Static IP configuration applied"
    else
        echo "Keeping current configuration"
    fi
fi

# Step 4: Release current DHCP lease and stop DHCP processes
echo "Releasing DHCP lease and stopping DHCP processes..."
dhclient -r "$PRIMARY_IF" 2>/dev/null || echo "No active DHCP lease found"

# Kill any remaining dhclient processes
pkill -f "dhclient.*$PRIMARY_IF" 2>/dev/null || true
pkill dhclient 2>/dev/null || true

# Step 5: Clean up DHCP client files completely
echo "Cleaning up DHCP client files..."
rm -f /var/lib/dhcp/dhclient*.leases*
rm -f /var/lib/dhclient/dhclient*.leases*
rm -f /var/lib/NetworkManager/dhclient*.leases*
rm -f /var/run/dhclient*.pid
rm -f /var/run/dhclient*.lease

# Remove DHCP client configuration files
find /etc -name "dhclient*.conf" 2>/dev/null | while read -r file; do
    echo "Removing DHCP client config: $file"
    rm -f "$file"
done

# Step 6: Clean up backup files (optional - uncomment if desired)
# echo "Cleaning up backup files..."
# find /etc/sysconfig/network-scripts/ -name "ifcfg-*.backup.*" -delete
# find /etc/sysconfig/ -name "network.backup.*" -delete

# Step 7: Ensure interface is properly configured
if [[ ! -f "$IFCFG_FILE" ]] || ! grep -q "BOOTPROTO" "$IFCFG_FILE" 2>/dev/null; then
    echo "Interface file missing or invalid. Creating basic configuration..."
    
    # Prompt for static IP if no backup exists
    if [[ "$FORCE_MODE" == false ]]; then
        read -p "No backup found. Would you like to set a static IP? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter IP address (e.g., 192.168.1.100): " STATIC_IP
            read -p "Enter netmask (e.g., 255.255.255.0): " NETMASK
            read -p "Enter gateway (e.g., 192.168.1.1): " GATEWAY
            
            HWADDR=$(ip link show "$PRIMARY_IF" 2>/dev/null | awk '/ether/ {print $2}' || echo "")
            
            cat > "$IFCFG_FILE" <<EOF
DEVICE=$PRIMARY_IF
$([ -n "$HWADDR" ] && echo "HWADDR=$HWADDR")
ONBOOT=yes
BOOTPROTO=none
IPADDR=$STATIC_IP
NETMASK=$NETMASK
GATEWAY=$GATEWAY
TYPE=Ethernet
EOF
            echo "Static IP configuration applied"
        else
            # Set to DHCP as fallback
            HWADDR=$(ip link show "$PRIMARY_IF" 2>/dev/null | awk '/ether/ {print $2}' || echo "")
            cat > "$IFCFG_FILE" <<EOF
DEVICE=$PRIMARY_IF
$([ -n "$HWADDR" ] && echo "HWADDR=$HWADDR")
BOOTPROTO=dhcp
TYPE=Ethernet
ONBOOT=yes
EOF
            echo "DHCP configuration applied as fallback"
        fi
    else
        # In force mode, just set to DHCP
        HWADDR=$(ip link show "$PRIMARY_IF" 2>/dev/null | awk '/ether/ {print $2}' || echo "")
        cat > "$IFCFG_FILE" <<EOF
DEVICE=$PRIMARY_IF
$([ -n "$HWADDR" ] && echo "HWADDR=$HWADDR")
BOOTPROTO=dhcp
TYPE=Ethernet
ONBOOT=yes
EOF
        echo "DHCP configuration applied (force mode)"
    fi
fi

# Step 8: Restart network
echo "Restarting network service..."
systemctl restart network

# Step 9: Verify network is working
echo "Verifying network connectivity..."
sleep 3

# Show current IP
CURRENT_IP=$(ip addr show "$PRIMARY_IF" 2>/dev/null | awk '/inet / && !/127.0.0.1/ {print $2}' | cut -d/ -f1)

if [ -n "$CURRENT_IP" ]; then
    echo "Network interface is up with IP: $CURRENT_IP"
else
    echo "Warning: No IP address assigned to $PRIMARY_IF"
fi

if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo "Network connectivity restored successfully"
else
    echo "Warning: Network connectivity test failed. You may need to manually configure network settings."
fi

# Step 10: Final cleanup and summary
echo ""
echo "=== DHCP Client Uninstallation Complete ==="
echo "Actions performed:"
echo "  ✓ DHCP lease released"
echo "  ✓ DHCP client processes stopped"
echo "  ✓ Network configuration restored from backup"
echo "  ✓ DHCP client files cleaned up"
echo "  ✓ Network service restarted"
echo ""
if [ -n "$CURRENT_IP" ]; then
    echo "Current network status: $PRIMARY_IF has IP $CURRENT_IP"
else
    echo "Current network status: $PRIMARY_IF has no IP assigned"
fi
echo ""
echo "Note: Backup files have been preserved for safety."
echo "You can manually remove them from:"
echo "  - /etc/sysconfig/network-scripts/*.backup.*"
echo "  - /etc/sysconfig/network.backup.*"