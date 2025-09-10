#!/bin/bash

#--------------------------------------------------------------
# Script Name: OpenVPN Server Cleanup for CentOS 7
# Description: Removes OpenVPN server, EasyRSA, and all server configs
# Usage: sudo bash reset-server.sh
# Version: 1.1
# Reference: https://github.com/angristan/openvpn-install/tree/master
#--------------------------------------------------------------

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Must run as root"
    exit 1
fi

echo "[INFO] OpenVPN Server Cleanup"

# Detect current configuration
if [[ -f /etc/openvpn/server/server.conf ]]; then
    PORT=$(grep '^port ' /etc/openvpn/server/server.conf | cut -d " " -f 2 || echo "1194")
    PROTOCOL=$(grep '^proto ' /etc/openvpn/server/server.conf | cut -d " " -f 2 || echo "udp")
else
    PORT="1194"
    PROTOCOL="udp"
fi

echo "[INFO] Detected OpenVPN configuration: $PROTOCOL port $PORT"

# Stop server services
echo "[+] Stopping OpenVPN server services..."
systemctl stop openvpn-server@server || true
systemctl disable openvpn-server@server || true
systemctl stop openvpn@server || true
systemctl disable openvpn@server || true

# Kill any OpenVPN processes
pkill openvpn || true

# Remove custom service files
echo "[+] Removing custom service files..."
rm -f /etc/systemd/system/openvpn-server@.service
rm -f /etc/systemd/system/openvpn@.service
systemctl daemon-reload

# Clean advanced iptables setup (if exists)
echo "[+] Cleaning advanced firewall rules..."
systemctl stop iptables-openvpn 2>/dev/null || true
systemctl disable iptables-openvpn 2>/dev/null || true
rm -f /etc/systemd/system/iptables-openvpn.service
rm -f /etc/iptables/add-openvpn-rules.sh
rm -f /etc/iptables/rm-openvpn-rules.sh

# Clean basic iptables NAT rules
echo "[+] Cleaning basic firewall rules..."
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -j MASQUERADE 2>/dev/null || true

# Try different interface names
for interface in ens33 eth0 enp0s3; do
    iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o "$interface" -j MASQUERADE 2>/dev/null || true
done

# Save iptables if service exists
service iptables save 2>/dev/null || iptables-save > /etc/sysconfig/iptables 2>/dev/null || true

# SELinux cleanup
echo "[+] Checking SELinux..."
if hash sestatus 2>/dev/null; then
    if sestatus | grep "Current mode" | grep -qs "enforcing"; then
        if [[ $PORT != '1194' ]]; then
            echo "[+] Removing SELinux port policy for $PROTOCOL port $PORT"
            semanage port -d -t openvpn_port_t -p "$PROTOCOL" "$PORT" 2>/dev/null || true
        fi
    fi
fi

# Remove packages
echo "[+] Removing packages..."
yum remove -y openvpn easy-rsa

# Comprehensive cleanup
echo "[+] Removing configuration files..."
rm -rf /etc/openvpn
rm -rf /usr/share/easy-rsa
rm -rf /usr/share/doc/openvpn*
rm -rf /var/log/openvpn*

# Clean client files from home directories
echo "[+] Removing client configuration files..."
find /home/ -maxdepth 2 -name "*.ovpn" -delete 2>/dev/null || true
find /root/ -maxdepth 1 -name "*.ovpn" -delete 2>/dev/null || true

# Disable IP forwarding
echo "[+] Disabling IP forwarding..."
if [[ -f /etc/sysctl.conf ]]; then
    sed -i 's/^net.ipv4.ip_forward.*/#net.ipv4.ip_forward=0/' /etc/sysctl.conf
fi

# Also check for sysctl.d configuration
rm -f /etc/sysctl.d/99-openvpn.conf

# Apply sysctl changes
sysctl -p 2>/dev/null || true

# Remove network interfaces
echo "[+] Removing network interfaces..."
ip link delete tun0 2>/dev/null || true

# Unbound cleanup (if exists)
if [[ -e /etc/unbound/openvpn.conf ]]; then
    echo "[+] Removing Unbound DNS configuration..."
    rm -f /etc/unbound/openvpn.conf
    systemctl restart unbound 2>/dev/null || true
fi

echo ""
echo "[SUCCESS] OpenVPN server removal completed!"
echo "[INFO] Configuration removed: $PROTOCOL port $PORT"
echo "[INFO] All client files and certificates deleted"