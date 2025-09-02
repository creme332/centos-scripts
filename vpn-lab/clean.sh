#!/bin/bash
# Cleanup script for OpenVPN + EasyRSA on CentOS 7

set -euo pipefail

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

echo "[+] Stopping and disabling OpenVPN services..."
systemctl stop openvpn@server 2>/dev/null || true
systemctl disable openvpn@server 2>/dev/null || true

# Stop any other OpenVPN services
for svc in $(systemctl list-unit-files | grep openvpn | awk '{print $1}'); do
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
done

echo "[+] Removing OpenVPN and EasyRSA packages..."
yum remove -y openvpn easy-rsa

echo "[+] Removing configuration directories..."
rm -rf /etc/openvpn \
       /usr/share/easy-rsa \
       ~/easy-rsa \
       /var/log/openvpn

echo "[+] Cleaning up firewall rules..."
firewall-cmd --remove-service=openvpn --permanent 2>/dev/null || true
# Remove masquerade for typical VPN subnet if it exists
firewall-cmd --zone=public --remove-masquerade --permanent 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

echo "[+] Reverting sysctl changes (IP forwarding)..."
if grep -q "net.ipv4.ip_forward" /etc/sysctl.conf; then
    sed -i 's/^net.ipv4.ip_forward.*/# net.ipv4.ip_forward=0/' /etc/sysctl.conf
else
    echo "# net.ipv4.ip_forward=0" >> /etc/sysctl.conf
fi
sysctl -p 2>/dev/null || true

echo "[+] Verifying removal..."
systemctl list-unit-files | grep openvpn || echo "No OpenVPN services remain."
ls -l /etc/openvpn 2>/dev/null || echo "/etc/openvpn removed."

echo "[✔] OpenVPN and EasyRSA have been fully removed."
