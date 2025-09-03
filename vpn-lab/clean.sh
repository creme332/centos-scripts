#!/bin/bash

#--------------------------------------------------------------
# Script Name: OpenVPN Complete Cleanup for CentOS 7
# Description: Safely removes OpenVPN, EasyRSA, and all configurations
#              Works on both server and client machines
# Usage: sudo bash cleanup.sh
# Version: 1.0
# Author: creme332
#--------------------------------------------------------------

set -euo pipefail

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] This script must be run as root"
    exit 1
fi

echo "[INFO] OpenVPN Complete Cleanup for CentOS 7"
echo ""

# --- Stop OpenVPN Services ---
echo "[+] Stopping and disabling OpenVPN services..."

# Stop server services (new systemd naming)
systemctl stop openvpn-server@server 2>/dev/null || true
systemctl disable openvpn-server@server 2>/dev/null || true

# Stop client services
for client_conf in /etc/openvpn/client/*.conf 2>/dev/null; do
    if [[ -f "$client_conf" ]]; then
        client_name=$(basename "$client_conf" .conf)
        systemctl stop "openvpn-client@$client_name" 2>/dev/null || true
        systemctl disable "openvpn-client@$client_name" 2>/dev/null || true
        echo "  Stopped client service: $client_name"
    fi
done

# Stop any legacy OpenVPN services
systemctl stop openvpn@server 2>/dev/null || true
systemctl disable openvpn@server 2>/dev/null || true

# Stop any running OpenVPN processes
pkill openvpn 2>/dev/null || true

echo "  OpenVPN services stopped"

# --- Remove Packages ---
echo "[+] Removing OpenVPN and EasyRSA packages..."
yum remove -y openvpn easy-rsa 2>/dev/null || true

# --- Remove Configuration Directories ---
echo "[+] Removing configuration directories..."
rm -rf /etc/openvpn \
       /usr/share/easy-rsa \
       ~/easy-rsa \
       /var/log/openvpn* \
       /tmp/openvpn* 2>/dev/null || true

# Remove client utility scripts if they exist
echo "[+] Removing VPN utility scripts..."
rm -f /usr/local/bin/vpn-connect \
      /usr/local/bin/vpn-disconnect \
      /usr/local/bin/vpn-status \
      /usr/local/bin/vpn-verify 2>/dev/null || true

# Remove any .ovpn files from common locations
echo "[+] Removing .ovpn configuration files..."
find /root -name "*.ovpn" -delete 2>/dev/null || true
if [[ -n "${SUDO_USER:-}" ]]; then
    user_home=$(eval echo "~$SUDO_USER")
    find "$user_home" -name "*.ovpn" -delete 2>/dev/null || true
fi

# --- Clean Firewall Rules ---
echo "[+] Cleaning up firewall rules..."

# Clean firewalld rules (if firewalld is installed)
if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --remove-service=openvpn --permanent 2>/dev/null || true
    firewall-cmd --zone=public --remove-masquerade --permanent 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo "  Firewalld rules cleaned"
fi

# Clean iptables rules (more important for your setup)
echo "  Cleaning iptables rules..."

# Remove OpenVPN-specific NAT rules
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -j MASQUERADE 2>/dev/null || true

# Remove any rules mentioning tun0
iptables-save | grep -v tun0 | iptables-restore 2>/dev/null || true

# Save cleaned iptables rules
iptables-save > /etc/sysconfig/iptables 2>/dev/null || true

echo "  Iptables rules cleaned"

# --- Revert System Configuration ---
echo "[+] Reverting system configuration..."

# Revert IP forwarding
if [[ -f /etc/sysctl.conf ]]; then
    # Comment out or remove IP forwarding line
    sed -i 's/^net.ipv4.ip_forward.*/#net.ipv4.ip_forward=0/' /etc/sysctl.conf
    
    # Apply changes
    sysctl -p >/dev/null 2>&1 || true
    echo "  IP forwarding disabled"
fi

# --- Network Interface Cleanup ---
echo "[+] Cleaning up network interfaces..."

# Remove any lingering tun interfaces
for tun_if in $(ip link show | grep tun | awk -F': ' '{print $2}'); do
    ip link delete "$tun_if" 2>/dev/null || true
    echo "  Removed interface: $tun_if"
done

# --- Verification ---
echo "[+] Verifying cleanup..."

# Check for remaining services
REMAINING_SERVICES=$(systemctl list-unit-files | grep openvpn | wc -l)
if [[ $REMAINING_SERVICES -eq 0 ]]; then
    echo "  ✓ No OpenVPN services remain"
else
    echo "  ⚠ Some OpenVPN services may still exist"
    systemctl list-unit-files | grep openvpn || true
fi

# Check for remaining processes
if pgrep openvpn >/dev/null 2>&1; then
    echo "  ⚠ OpenVPN processes still running:"
    pgrep -f openvpn || true
else
    echo "  ✓ No OpenVPN processes running"
fi

# Check for remaining config directories
if [[ -d /etc/openvpn ]]; then
    echo "  ⚠ /etc/openvpn still exists"
else
    echo "  ✓ /etc/openvpn removed"
fi

# Check for tun interfaces
if ip link show | grep -q tun; then
    echo "  ⚠ TUN interfaces still exist:"
    ip link show | grep tun || true
else
    echo "  ✓ No TUN interfaces remain"
fi

echo ""
echo "[SUCCESS] OpenVPN cleanup completed"
echo ""
echo "System has been restored to pre-OpenVPN state."
echo "You may want to reboot to ensure all changes take effect."