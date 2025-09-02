#!/bin/bash

#-------------------------------------------------------------- 
# Script Name: Setup OpenVPN Client for CentOS 7
# Description: Installs OpenVPN client and configures it to connect
#              to an OpenVPN server using a provided .ovpn config file.
#              Optimized for CentOS 7 systems.
# Usage: bash client.sh <path_to_config_file.ovpn>
# Version: 0.0
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - CentOS 7 with root privileges
# - .ovpn configuration file from OpenVPN server
# - Internet connectivity for package installation
#--------------------------------------------------------------
# Notes:
# - Installs OpenVPN client package via EPEL
# - Copies configuration file to appropriate location
# - Provides commands to connect/disconnect from VPN
# - Shows public IP before/after connection to verify VPN works
# - Creates systemd service for automatic connection (optional)
#--------------------------------------------------------------

set -euo pipefail

# --- Variables ---
CONFIG_FILE="$1"
CLIENT_NAME=""

# --- Functions ---
install_openvpn() {
    echo "[INFO] Checking OpenVPN client installation..."
    
    # Check if OpenVPN is already installed
    if rpm -q openvpn >/dev/null 2>&1; then
        echo "[OK] OpenVPN client already installed"
        return
    fi
    
    echo "[INFO] Installing OpenVPN client..."
    
    # Install EPEL repository if not already installed
    if ! rpm -q epel-release >/dev/null 2>&1; then
        yum install -y epel-release
    else
        echo "[OK] EPEL repository already installed"
    fi
    
    # Install OpenVPN and curl
    yum install -y openvpn curl
    
    echo "[OK] OpenVPN client installed"
}

setup_config() {
    local config_file="$1"
    local config_name
    config_name=$(basename "$config_file" .ovpn)
    CLIENT_NAME="$config_name"
    
    local target_config="/etc/openvpn/client/${config_name}.conf"
    
    # Create client config directory
    mkdir -p /etc/openvpn/client
    
    # Check if config already exists
    if [[ -f "$target_config" ]]; then
        echo "[INFO] Configuration file already exists at $target_config"
        
        # Compare files to see if they're different
        if ! cmp -s "$config_file" "$target_config"; then
            echo "[WARNING] Existing config differs from provided config."
            read -p "Do you want to overwrite the existing configuration? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cp "$config_file" "$target_config"
                chmod 600 "$target_config"
                echo "[OK] Configuration file updated"
            else
                echo "[INFO] Keeping existing configuration"
            fi
        else
            echo "[OK] Configuration file is identical, no update needed"
        fi
    else
        # Copy config file
        cp "$config_file" "$target_config"
        chmod 600 "$target_config"
        echo "[OK] Configuration file copied to $target_config"
    fi
}

get_public_ip() {
    local ip=""
    
    # Try multiple services to get public IP
    for service in "ifconfig.me" "icanhazip.com" "ipinfo.io/ip" "checkip.amazonaws.com"; do
        ip=$(curl -s --connect-timeout 5 "$service" 2>/dev/null | grep -oE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' || echo "")
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return
        fi
    done
    
    echo "Unable to determine"
}

create_connection_scripts() {
    local client_name="$1"
    
    echo "[INFO] Setting up VPN connection scripts..."
    
    # Check if scripts already exist
    local scripts_exist=false
    for script in "vpn-connect" "vpn-disconnect" "vpn-status"; do
        if [[ -f "/usr/local/bin/$script" ]]; then
            scripts_exist=true
            break
        fi
    done
    
    if [[ "$scripts_exist" == true ]]; then
        echo "[INFO] VPN scripts already exist."
        read -p "Do you want to recreate the VPN scripts? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "[INFO] Keeping existing VPN scripts"
            return
        fi
    fi
    
    # Create connection script
    cat > "/usr/local/bin/vpn-connect" << 'CONNECT_EOF'
#!/bin/bash
CLIENT_NAME="CLIENT_NAME_PLACEHOLDER"

echo "Getting public IP before VPN connection..."
BEFORE_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "Unable to determine")
echo "Public IP before VPN: $BEFORE_IP"
echo ""
echo "Connecting to VPN..."
systemctl start openvpn-client@${CLIENT_NAME}
echo "Waiting for VPN connection to establish..."
sleep 5

# Wait for VPN interface to come up (max 30 seconds)
for i in $(seq 1 30); do
    if ip addr show tun0 >/dev/null 2>&1; then
        echo "VPN interface is up!"
        break
    fi
    sleep 1
done

echo ""
echo "VPN Status:"
systemctl status openvpn-client@${CLIENT_NAME} --no-pager -l
echo ""
echo "Getting public IP after VPN connection..."
AFTER_IP=$(curl -s --connect-timeout 10 ifconfig.me 2>/dev/null || echo "Unable to determine")
echo "Public IP after VPN: $AFTER_IP"
echo ""

if [[ "$BEFORE_IP" != "$AFTER_IP" && "$AFTER_IP" != "Unable to determine" ]]; then
    echo "✓ SUCCESS: VPN is working! Your IP has changed."
else
    echo "⚠ WARNING: VPN may not be working properly. IP did not change or could not be determined."
fi
CONNECT_EOF
    
    # Replace placeholder with actual client name
    sed -i "s/CLIENT_NAME_PLACEHOLDER/$client_name/g" "/usr/local/bin/vpn-connect"
    
    # Create disconnection script
    cat > "/usr/local/bin/vpn-disconnect" << 'DISCONNECT_EOF'
#!/bin/bash
CLIENT_NAME="CLIENT_NAME_PLACEHOLDER"

echo "Getting current public IP..."
CURRENT_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "Unable to determine")
echo "Current public IP: $CURRENT_IP"
echo ""
echo "Disconnecting from VPN..."
systemctl stop openvpn-client@${CLIENT_NAME}
sleep 3
echo ""
echo "Getting public IP after disconnect..."
AFTER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "Unable to determine")
echo "Public IP after disconnect: $AFTER_IP"
echo ""
if [[ "$CURRENT_IP" != "$AFTER_IP" && "$AFTER_IP" != "Unable to determine" ]]; then
    echo "✓ VPN disconnected successfully. IP has changed back."
else
    echo "VPN disconnected."
fi
DISCONNECT_EOF
    
    # Replace placeholder with actual client name
    sed -i "s/CLIENT_NAME_PLACEHOLDER/$client_name/g" "/usr/local/bin/vpn-disconnect"
    
    # Create status script
    cat > "/usr/local/bin/vpn-status" << 'STATUS_EOF'
#!/bin/bash
CLIENT_NAME="CLIENT_NAME_PLACEHOLDER"

echo "=== VPN Service Status ==="
systemctl status openvpn-client@${CLIENT_NAME} --no-pager -l
echo ""
echo "=== VPN Interface Information ==="
if ip addr show tun0 2>/dev/null; then
    echo ""
    echo "VPN Routes:"
    ip route show | grep tun0
else
    echo "VPN interface (tun0) not found - VPN is not connected"
fi
echo ""
echo "=== Public IP Information ==="
CURRENT_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "Unable to determine")
echo "Current public IP: $CURRENT_IP"
echo ""
echo "=== DNS Information ==="
echo "Current DNS servers:"
cat /etc/resolv.conf | grep nameserver
STATUS_EOF
    
    # Replace placeholder with actual client name
    sed -i "s/CLIENT_NAME_PLACEHOLDER/$client_name/g" "/usr/local/bin/vpn-status"
    
    chmod +x /usr/local/bin/vpn-connect
    chmod +x /usr/local/bin/vpn-disconnect  
    chmod +x /usr/local/bin/vpn-status
    
    echo "[OK] VPN connection scripts created/updated:"
    echo "  - vpn-connect    : Connect to VPN and show IP change"
    echo "  - vpn-disconnect : Disconnect from VPN and show IP change"
    echo "  - vpn-status     : Show detailed VPN status and current IP"
}

# --- Main Script ---

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

echo "[INFO] Setting up OpenVPN server with client: $CLIENT_NAME"

# Check if config file is provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <path_to_config_file.ovpn>"
    echo "Example: $0 /home/user/client1.ovpn"
    exit 1
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Configuration file not found: $CONFIG_FILE"
    exit 1
fi

echo "[INFO] Setting up OpenVPN client on CentOS 7 with config: $CONFIG_FILE"

# Check if we're on CentOS 7
if [[ ! -f /etc/redhat-release ]] || ! grep -q "CentOS Linux release 7" /etc/redhat-release; then
    echo "[WARNING] This script is optimized for CentOS 7. Proceeding anyway..."
fi

# Check if this is a re-run
if [[ -d /etc/openvpn/client ]] && rpm -q openvpn >/dev/null 2>&1; then
    echo "[INFO] Detected existing OpenVPN client installation. Running in update mode..."
    echo "[INFO] Script is idempotent - safe to re-run multiple times."
    echo ""
fi

# Install OpenVPN
install_openvpn

# Setup configuration
setup_config "$CONFIG_FILE"

# Create connection scripts
create_connection_scripts "$CLIENT_NAME"

echo ""
echo "[SUCCESS] OpenVPN client setup complete!"
echo ""
echo "=== TESTING VPN CONNECTION ==="
echo ""
echo "Current public IP (before VPN):"
BEFORE_VPN_IP=$(get_public_ip)
echo "$BEFORE_VPN_IP"
echo ""
echo "To connect to VPN and see IP change:"
echo "  vpn-connect"
echo ""
echo "To disconnect from VPN:"
echo "  vpn-disconnect"
echo ""
echo "To check VPN status and current IP:"
echo "  vpn-status"
echo ""
echo "Manual connection (alternative):"
echo "  systemctl start openvpn-client@${CLIENT_NAME}"
echo ""
echo "Manual disconnection (alternative):"
echo "  systemctl stop openvpn-client@${CLIENT_NAME}"
echo ""
echo "=========================================="
echo "QUICK START:"
echo "1. Run 'vpn-connect' to connect to VPN"
echo "2. Verify your IP changed in the output"
echo "3. Use 'vpn-status' to check connection"
echo "4. Use 'vpn-disconnect' to disconnect"
echo "=========================================="