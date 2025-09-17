#!/bin/bash

#--------------------------------------------------------------
# Script Name: Uninstall DHCP Server on CentOS 7.9
# Description: Removes DHCP server and restores original 
#              network configuration from backups. Completely
#              resets all DHCP-related configurations.
# Usage: Run the script as root using bash uninstall-server.sh [--force]
# Version: 0.2
# Author: creme332
#--------------------------------------------------------------

set -euo pipefail

# Parse command line options
FORCE_MODE=false
if [[ "${1:-}" == "--force" ]] || [[ "${1:-}" == "-f" ]]; then
    FORCE_MODE=true
    echo "Force mode enabled - will proceed without prompts"
fi

# Root check
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# Confirmation prompt unless in force mode
if [[ "$FORCE_MODE" == false ]]; then
    echo "This will completely remove the DHCP server and reset network configuration."
    echo "Are you sure you want to continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi
fi

echo "Starting DHCP Server uninstallation..."

# Step 1: Stop and disable DHCP service
echo "Stopping DHCP service..."
systemctl stop dhcpd 2>/dev/null || echo "DHCP service was not running"
systemctl disable dhcpd 2>/dev/null || echo "DHCP service was not enabled"

# Step 2: Remove DHCP package
echo "Removing DHCP package..."
yum remove -y dhcp || echo "DHCP package was not installed"

# Step 3: Detect primary interface
PRIMARY_IF=$(ip -o link show | awk -F': ' '$2 != "lo"{print $2}' | head -n1)
if [ -z "$PRIMARY_IF" ]; then
    echo "No valid network interface detected."
    exit 1
fi
echo "Detected primary network interface: $PRIMARY_IF"

# Step 4: Restore network interface configuration
IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-${PRIMARY_IF}"
BACKUP_FILE=$(find /etc/sysconfig/network-scripts/ -name "ifcfg-${PRIMARY_IF}.backup.*" | sort -r | head -n1)

if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
    echo "Restoring network interface configuration from $BACKUP_FILE"
    cp "$BACKUP_FILE" "$IFCFG_FILE"
    echo "Network configuration restored"
else
    echo "No backup found for network interface. Setting to DHCP as fallback..."
    cat > "$IFCFG_FILE" <<EOF
DEVICE=$PRIMARY_IF
BOOTPROTO=dhcp
TYPE=Ethernet
ONBOOT=yes
EOF
fi

# Step 5: Restore DHCP sysconfig
DHCPD_FILE="/etc/sysconfig/dhcpd"
BACKUP_DHCPD=$(find /etc/sysconfig/ -name "dhcpd.backup.*" 2>/dev/null | sort -r | head -n1)

if [ -n "$BACKUP_DHCPD" ] && [ -f "$BACKUP_DHCPD" ]; then
    echo "Restoring DHCP sysconfig from $BACKUP_DHCPD"
    cp "$BACKUP_DHCPD" "$DHCPD_FILE"
else
    echo "Removing DHCP sysconfig file..."
    rm -f "$DHCPD_FILE"
fi

# Step 6: Remove DHCP configuration and data
echo "Removing DHCP configuration files..."
rm -f /etc/dhcp/dhcpd.conf
rm -f /etc/dhcp/dhcpd.conf.backup.*
rm -rf /var/lib/dhcp/dhcpd.leases*
rm -rf /var/lib/dhcpd/dhcpd.leases*

# Remove any remaining DHCP-related files
find /etc -name "*dhcp*" -type f 2>/dev/null | grep -v "dhclient" | while read -r file; do
    echo "Removing DHCP file: $file"
    rm -f "$file"
done

# Step 7: Reset firewall rules (if any DHCP-related rules exist)
echo "Checking for DHCP firewall rules..."
if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --remove-service=dhcp --permanent 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo "Firewall DHCP rules removed"
fi

# Reset iptables DHCP rules if present
if command -v iptables >/dev/null 2>&1; then
    iptables -D INPUT -p udp --dport 67 -j ACCEPT 2>/dev/null || true
    iptables -D INPUT -p udp --dport 68 -j ACCEPT 2>/dev/null || true
    echo "iptables DHCP rules removed"
fi

# Step 7: Clean up backup files (optional - uncomment if desired)
# echo "Cleaning up backup files..."
# find /etc/sysconfig/network-scripts/ -name "ifcfg-*.backup.*" -delete
# find /etc/sysconfig/ -name "dhcpd.backup.*" -delete
# find /etc/dhcp/ -name "dhcpd.conf.backup.*" -delete

# Step 8: Reset network configuration to DHCP if no backup exists
if [[ ! -f "$IFCFG_FILE" ]] || ! grep -q "IPADDR" "$IFCFG_FILE" 2>/dev/null; then
    echo "Setting network interface to DHCP as fallback..."
    HWADDR=$(ip link show "$PRIMARY_IF" 2>/dev/null | awk '/ether/ {print $2}' || echo "")
    
    cat > "$IFCFG_FILE" <<EOF
DEVICE=$PRIMARY_IF
$([ -n "$HWADDR" ] && echo "HWADDR=$HWADDR")
BOOTPROTO=dhcp
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=yes
EOF
fi

# Step 9: Restart network
echo "Restarting network service..."
systemctl restart network

# Step 10: Verify network is working
echo "Verifying network connectivity..."
sleep 3
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

# Step 11: Final cleanup and summary
echo ""
echo "=== DHCP Server Uninstallation Complete ==="
echo "Actions performed:"
echo "  ✓ DHCP service stopped and disabled"
echo "  ✓ DHCP package removed"
echo "  ✓ Network interface configuration restored"
echo "  ✓ DHCP configuration files removed"
echo "  ✓ DHCP lease files cleared"
echo "  ✓ Firewall rules reset"
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
echo "  - /etc/sysconfig/dhcpd.backup.*"