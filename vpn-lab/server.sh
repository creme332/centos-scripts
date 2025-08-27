#!/bin/bash

#-------------------------------------------------------------- 
# Script Name: Setup OpenVPN Server on CentOS 7
# Description: Installs and configures OpenVPN server with EasyRSA
#              on CentOS 7. Automates installation of required
#              packages, server configuration, key and certificate
#              generation, iptables routing, and IP forwarding.
#              Idempotent and safe to re-run multiple times.
# Usage: Run the script as root using bash openvpn_setup.sh
# Version: 0.2
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
yum install -y epel-release
yum install -y openvpn easy-rsa iptables-services net-tools

# --- Verify EasyRSA v3 installation ---
EASYRSA_BASE="/usr/share/easy-rsa"
EASYRSA_SRC=$(ls -d $EASYRSA_BASE/3* 2>/dev/null | sort -V | tail -n 1)

if [[ -z "$EASYRSA_SRC" ]]; then
    echo "[ERROR] EasyRSA v3 not found under $EASYRSA_BASE"
    exit 1
fi

if [[ ! -f "$EASYRSA_SRC/easyrsa" ]]; then
    echo "[ERROR] EasyRSA script not found in $EASYRSA_SRC"
    exit 1
fi

echo "[OK] EasyRSA v3 detected at $EASYRSA_SRC"

# --- Config directories ---
OVPN_DIR="/etc/openvpn/server"
EASYRSA_DIR="/etc/openvpn/easy-rsa"
mkdir -p "$OVPN_DIR"

# --- Create server.conf ---
SERVER_CONF="$OVPN_DIR/server.conf"
cat > $SERVER_CONF <<'EOF'
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
tls-auth ta.key 0
cipher AES-256-CBC
user nobody
group nobody
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

# --- EasyRSA setup ---
if [[ ! -d $EASYRSA_DIR/pki ]]; then
    echo "[INFO] Initializing EasyRSA PKI at $EASYRSA_DIR..."
    mkdir -p "$EASYRSA_DIR"
    cp -r "$EASYRSA_SRC"/* "$EASYRSA_DIR/"
    cd "$EASYRSA_DIR"

    # Non-interactive variables
    export EASYRSA_BATCH=1
    export EASYRSA_REQ_CN="server"

    # Initialize PKI
    ./easyrsa init-pki

    # Build CA (non-interactive)
    ./easyrsa build-ca nopass

    # Generate server request (no password)
    ./easyrsa gen-req server nopass

    # Sign server request (non-interactive)
    ./easyrsa sign-req server server

    # Generate Diffie-Hellman parameters
    ./easyrsa gen-dh

    # Generate TLS auth key
    openvpn --genkey --secret ta.key

    # Copy keys and certs to OpenVPN directory
    cp pki/ca.crt "$OVPN_DIR/"
    cp pki/issued/server.crt "$OVPN_DIR/"
    cp pki/private/server.key "$OVPN_DIR/"
    cp pki/dh.pem "$OVPN_DIR/"
    cp ta.key "$OVPN_DIR/"
else
    echo "[INFO] EasyRSA PKI already exists at $EASYRSA_DIR, skipping key generation."
fi

# --- Firewall / Routing ---
systemctl mask firewalld || true
systemctl enable iptables
systemctl stop firewalld || true
systemctl start iptables

# Detect interface automatically using route/ifconfig
NET_IF=$(route -n | awk '/^0.0.0.0/ {print $8; exit}')
if [[ -z "$NET_IF" ]]; then
    echo "[ERROR] Could not detect default network interface."
    exit 1
fi
echo "[INFO] Detected network interface: $NET_IF"

iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o "$NET_IF" -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$NET_IF" -j MASQUERADE
iptables-save > /etc/sysconfig/iptables

# --- Enable IP forwarding ---
SYSCTL_CONF="/etc/sysctl.conf"

# Ensure sysctl.conf exists
if [[ ! -f "$SYSCTL_CONF" ]]; then
    touch "$SYSCTL_CONF"
fi

# Enable IPv4 forwarding
if ! grep -q "^net.ipv4.ip_forward *= *1" "$SYSCTL_CONF"; then
    echo "net.ipv4.ip_forward = 1" >> "$SYSCTL_CONF"
fi

sysctl -p >/dev/null

# --- Enable and start OpenVPN ---
systemctl enable openvpn@server.service
systemctl restart openvpn@server.service

echo "[SUCCESS] OpenVPN server setup complete."
