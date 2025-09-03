#!/bin/bash

#--------------------------------------------------------------
# Script Name: OpenVPN Server Cleanup for CentOS 7
# Description: Removes OpenVPN server, EasyRSA, and all server configs
# Usage: sudo bash reset-server.sh
# Version: 1.0
# Author: creme332
#--------------------------------------------------------------

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Must run as root"
    exit 1
fi

echo "[INFO] OpenVPN Server Cleanup"

# Stop server services
echo "[+] Stopping OpenVPN server services..."
systemctl stop openvpn-server@server || true
systemctl disable openvpn-server@server || true
systemctl stop openvpn@server || true
systemctl disable openvpn@server || true

# Kill any OpenVPN processes
pkill openvpn || true

# Remove packages
echo "[+] Removing packages..."
yum remove -y openvpn easy-rsa

# Remove server directories
echo "[+] Removing server configuration..."
rm -rf /etc/openvpn
rm -rf /usr/share/easy-rsa
rm -rf /var/log/openvpn*

# Clean iptables NAT rules
echo "[+] Cleaning firewall rules..."
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -j MASQUERADE || true
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o ens33 -j MASQUERADE || true

# Try to save iptables if service exists
service iptables save || iptables-save > /etc/sysconfig/iptables || true

# Disable IP forwarding
echo "[+] Disabling IP forwarding..."
if [[ -f /etc/sysctl.conf ]]; then
    sed -i 's/^net.ipv4.ip_forward.*/#net.ipv4.ip_forward=0/' /etc/sysctl.conf
    sysctl -p || true
fi

# Remove any tun interfaces
echo "[+] Removing network interfaces..."
ip link delete tun0 || true

echo "[SUCCESS] OpenVPN server cleanup completed"