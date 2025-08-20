#!/bin/bash

#-------------------------------------------------------------- 
# Script Name: Setup OpenVPN Server on CentOS 7/8
# Description: Installs and configures OpenVPN server with EasyRSA
#              on CentOS 7. Automates installation of required
#              packages, server configuration, key and certificate
#              generation, iptables routing, and IP forwarding.
#              Idempotent and safe to re-run multiple times.
# Usage: Run the script as root using bash openvpn_setup.sh
# Version: 0.0
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - CentOS 7.x with root privileges
# - Domain or subdomain pointing to the server (for certificates)
# - Internet connectivity for package installation and updates
# - EPEL repository enabled (the script handles this automatically)
#--------------------------------------------------------------
# Notes:
# - Generates server and one default client certificate.
# - Updates /etc/sysctl.conf to enable IPv4 forwarding.
# - Configures iptables for NAT on the OpenVPN subnet (10.8.0.0/24).
# - Uses EasyRSA 2.0 for certificate management.
# - OpenVPN service is enabled and started via systemd.
# - Safe to re-run; existing keys, configs, and iptables rules are preserved.
#--------------------------------------------------------------

set -euo pipefail

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# --- YUM check ---
if yum repolist enabled >/dev/null 2>&1 && yum makecache fast >/dev/null 2>&1; then
    echo "[OK] YUM configured"
else
    echo "[ERROR] YUM not configured. Exiting."
    exit 1
fi

# --- Internet check ---
if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo "[ERROR] No internet connection. Exiting."
    exit 1
fi

# --- Install packages ---
echo "[INFO] Installing required packages..."
yum install -y epel-release openvpn easy-rsa iptables-services

# --- Config files ---
OVPN_DIR="/etc/openvpn"
EASYRSA_DIR="$OVPN_DIR/easy-rsa"
KEYS_DIR="$EASYRSA_DIR/keys"
SERVER_CONF="$OVPN_DIR/server.conf"

mkdir -p "$OVPN_DIR"

# Copy server.conf if not already configured
if [[ ! -f $SERVER_CONF ]]; then
    cp /usr/share/doc/openvpn-*/sample/sample-config-files/server.conf "$SERVER_CONF"
    echo "[INFO] OpenVPN server.conf copied"
fi

# Update server.conf (idempotent edits)
sed -i \
    -e 's/^;*dh.*/dh dh2048.pem/' \
    -e 's/^;*push "redirect-gateway.*/push "redirect-gateway def1 bypass-dhcp"/' \
    -e '/^;*push "dhcp-option DNS/c\push "dhcp-option DNS 8.8.8.8"\npush "dhcp-option DNS 8.8.4.4"' \
    -e 's/^;*user nobody/user nobody/' \
    -e 's/^;*group nobody/group nobody/' \
    "$SERVER_CONF"

# --- EasyRSA setup ---
if [[ ! -d $EASYRSA_DIR ]]; then
    mkdir -p "$KEYS_DIR"
    cp -rf /usr/share/easy-rsa/2.0/* "$EASYRSA_DIR"
    cp "$EASYRSA_DIR/openssl-1.0.0.cnf" "$EASYRSA_DIR/openssl.cnf"
fi

# Configure vars
VARS_FILE="$EASYRSA_DIR/vars"
if ! grep -q "KEY_CN" "$VARS_FILE"; then
    cat >> "$VARS_FILE" <<'EOF'

export KEY_COUNTRY="US"
export KEY_PROVINCE="NY"
export KEY_CITY="New York"
export KEY_ORG="MyOrg"
export KEY_EMAIL="admin@example.com"
export KEY_OU="IT"
export KEY_NAME="server"
export KEY_CN="openvpn.example.com"
EOF
fi

# --- Generate certs & keys ---
cd "$EASYRSA_DIR"
source ./vars

if [[ ! -f $KEYS_DIR/ca.crt ]]; then
    ./clean-all
    ./build-ca --batch
    ./build-key-server --batch server
    ./build-dh
    cp "$KEYS_DIR"/{dh2048.pem,ca.crt,server.crt,server.key} "$OVPN_DIR"
fi

# Create a default client cert (optional)
if [[ ! -f $KEYS_DIR/client.crt ]]; then
    ./build-key --batch client
fi

# --- Routing / iptables ---
systemctl mask firewalld || true
systemctl enable iptables
systemctl stop firewalld || true
systemctl start iptables

iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

iptables-save > /etc/sysconfig/iptables

# --- Enable IP forwarding ---
SYSCTL_CONF="/etc/sysctl.conf"
if ! grep -q "^net.ipv4.ip_forward *= *1" "$SYSCTL_CONF"; then
    echo "net.ipv4.ip_forward = 1" >> "$SYSCTL_CONF"
fi
sysctl -p >/dev/null

# --- Enable and start OpenVPN ---
systemctl enable openvpn@server.service
systemctl restart openvpn@server.service

echo "[SUCCESS] OpenVPN server setup complete."
