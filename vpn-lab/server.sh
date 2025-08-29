#!/bin/bash

#-------------------------------------------------------------- 
# Script Name: Setup OpenVPN Server on CentOS 7
# Description: Installs and configures OpenVPN server with EasyRSA
#              on CentOS 7. Automates installation of required
#              packages, server configuration, key and certificate
#              generation, iptables routing, and IP forwarding.
#              Also generates client certificates and creates
#              client configuration files.
#              Idempotent and safe to re-run multiple times.
# Usage: Run the script as root using bash server.sh [client_name]
# Version: 0.3
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - CentOS 7.x with root privileges
# - Domain or subdomain pointing to the server (for certificates)
# - Internet connectivity for package installation and updates
# - EPEL repository enabled (the script handles this automatically)
#--------------------------------------------------------------
# Notes:
# - Generates server and client certificates.
# - Updates /etc/sysctl.conf to enable IPv4 forwarding.
# - Configures iptables for NAT on the OpenVPN subnet (10.8.0.0/24).
# - Uses EasyRSA 3.x for certificate management.
# - OpenVPN service is enabled and started via systemd.
# - Safe to re-run; existing keys, configs, and iptables rules are preserved.
# - Creates client config files in /etc/openvpn/clients/
#--------------------------------------------------------------

set -euo pipefail

# --- Variables ---
CLIENT_NAME="${1:-client}"
SERVER_IP=""

# --- Validate client name ---
if [[ -z "${CLIENT_NAME// }" ]]; then
    echo "[ERROR] Client name cannot be empty. Exiting."
    exit 1
fi

# --- Functions ---
get_server_ip() {
    # Try to get public IP
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || curl -s icanhazip.com || echo "")
    
    if [[ -z "$SERVER_IP" ]]; then
        # Fallback to local IP
        SERVER_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
    fi
    
    if [[ -z "$SERVER_IP" ]]; then
        echo "[ERROR] Could not determine server IP address"
        exit 1
    fi
    
    echo "[INFO] Server IP detected as: $SERVER_IP"
}

generate_client_config() {
    local client_name="$1"
    local client_dir="/etc/openvpn/clients"
    local client_config="$client_dir/${client_name}.ovpn"
    
    mkdir -p "$client_dir"
    
    if [[ -f "$client_config" ]]; then
        echo "[INFO] Client config $client_config already exists, skipping generation."
        return
    fi
    
    cat > "$client_config" <<EOF
client
dev tun
proto udp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
verb 3
<ca>
$(cat "$EASYRSA_DIR/pki/ca.crt")
</ca>
<cert>
$(cat "$EASYRSA_DIR/pki/issued/${client_name}.crt")
</cert>
<key>
$(cat "$EASYRSA_DIR/pki/private/${client_name}.key")
</key>
<tls-auth>
$(cat "$EASYRSA_DIR/ta.key")
</tls-auth>
key-direction 1
EOF
    
    echo "[INFO] Client config generated: $client_config"
}

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

echo "[INFO] Setting up OpenVPN server with client: $CLIENT_NAME"

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
yum install -y openvpn easy-rsa iptables-services net-tools curl

# --- Get server IP ---
get_server_ip

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
    echo "[INFO] EasyRSA PKI already exists at $EASYRSA_DIR, skipping server key generation."
fi

# --- Generate client certificate ---
cd "$EASYRSA_DIR"

if [[ ! -f "pki/issued/${CLIENT_NAME}.crt" ]]; then
    echo "[INFO] Generating client certificate for: $CLIENT_NAME"
    
    # Set environment for client generation
    export EASYRSA_BATCH=1
    export EASYRSA_REQ_CN="$CLIENT_NAME"
    
    # Generate client request (no password)
    ./easyrsa gen-req "$CLIENT_NAME" nopass
    
    # Sign client request
    ./easyrsa sign-req client "$CLIENT_NAME"
    
    echo "[INFO] Client certificate generated for: $CLIENT_NAME"
else
    echo "[INFO] Client certificate for $CLIENT_NAME already exists, skipping generation."
fi

# --- Generate client config file ---
generate_client_config "$CLIENT_NAME"

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
echo "[INFO] Client configuration file created: /etc/openvpn/clients/${CLIENT_NAME}.ovpn"
echo "[INFO] Copy this file to your client device to connect to the VPN."
echo ""
echo "To generate additional client certificates, run:"
echo "  bash $0 <new_client_name>"