#!/bin/bash

#--------------------------------------------------------------
# Script Name: OpenVPN Client Cleanup for CentOS 7  
# Description: Removes OpenVPN client and all client configs
# Usage: sudo bash reset-client.sh
# Version: 1.0
# Author: creme332
#--------------------------------------------------------------

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Must run as root"
    exit 1
fi

echo "[INFO] OpenVPN Client Cleanup"

# Stop client services
echo "[+] Stopping OpenVPN client services..."
systemctl stop openvpn-client@client || true
systemctl disable openvpn-client@client || true

# Stop any other client services that might exist
for service in $(systemctl list-unit-files | grep openvpn-client | awk '{print $1}'); do
    systemctl stop "$service" || true
    systemctl disable "$service" || true
done

# Kill any OpenVPN processes
pkill openvpn || true

# Remove packages
echo "[+] Removing packages..."
yum remove -y openvpn

# Remove client directories
echo "[+] Removing client configuration..."
rm -rf /etc/openvpn

# Remove utility scripts
echo "[+] Removing VPN utility scripts..."
rm -f /usr/local/bin/vpn-connect
rm -f /usr/local/bin/vpn-disconnect
rm -f /usr/local/bin/vpn-status  
rm -f /usr/local/bin/vpn-verify

# Remove .ovpn files
echo "[+] Removing .ovpn files..."
rm -f /root/*.ovpn

# If script was run with sudo, also clean user's home directory
if [[ -n "${SUDO_USER:-}" ]]; then
    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    rm -f "$user_home"/*.ovpn || true
    echo "  Cleaned $user_home"
fi

# Remove any tun interfaces
echo "[+] Removing network interfaces..."
ip link delete tun0 || true

echo "[SUCCESS] OpenVPN client cleanup completed"