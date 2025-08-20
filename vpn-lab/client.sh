#-------------------------------------------------------------- 
# Script Name: Setup OpenVPN Client on Linux
# Description: Configures an OpenVPN client to connect to a remote
#              OpenVPN server. Copies certificates from the server
#              and generates a client.ovpn configuration file.
#              Works on CentOS/RHEL and other Linux distributions.
# Usage: Run the script as root using bash openvpn_client.sh
# Version: 0.0
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - CentOS 7 with root privileges
# - OpenVPN installed (script installs if missing)
# - Access to server's ca.crt, client.crt, and client.key files
# - Internet connectivity for package installation
#--------------------------------------------------------------

set -euo pipefail

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# --- Parameters ---
SERVER_IP="${1:-your_server_ip}"       # Server IP or domain
CLIENT_NAME="${2:-client}"             # Client key/certificate name
CERT_DIR="${3:-/etc/openvpn/client}"   # Directory to store certificates

# --- Install OpenVPN if missing ---
if ! command -v openvpn >/dev/null 2>&1; then
    echo "Installing OpenVPN..."
    if yum repolist enabled >/dev/null 2>&1; then
        yum install -y epel-release openvpn
    else
        echo "YUM not configured properly. Exiting."
        exit 1
    fi
fi

# --- Create certificate directory ---
mkdir -p "$CERT_DIR"

# --- Copy certificates from user-provided path ---
echo "Place ca.crt, ${CLIENT_NAME}.crt, and ${CLIENT_NAME}.key in $CERT_DIR"
echo "Skipping automatic copy for security reasons."

# --- Generate client.ovpn ---
CLIENT_OVPN="$CERT_DIR/client.ovpn"

if [[ ! -f "$CLIENT_OVPN" ]]; then
    cat > "$CLIENT_OVPN" <<EOL
client
dev tun
proto udp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
comp-lzo
verb 3
ca $CERT_DIR/ca.crt
cert $CERT_DIR/${CLIENT_NAME}.crt
key $CERT_DIR/${CLIENT_NAME}.key
EOL
    echo "Created client.ovpn at $CLIENT_OVPN"
else
    echo "client.ovpn already exists at $CLIENT_OVPN — skipping creation"
fi

# --- Instructions ---
echo "To connect:"
echo "sudo openvpn --config $CLIENT_OVPN"
echo "Ensure the certificates (ca.crt, ${CLIENT_NAME}.crt, ${CLIENT_NAME}.key) are present in $CERT_DIR"
