#!/bin/bash

#-------------------------------------------------------------- 
# Script Name: OpenVPN Client Setup for CentOS 7
# Description: Minimal setup - installs packages and prepares system
# Usage: bash client.sh [path_to_config_file.ovpn]
# Version: 1.0
# Author: creme332
#--------------------------------------------------------------

set -euo pipefail

# --- Functions ---
install_packages() {
    echo "[INFO] Installing required packages..."
    
    # Install EPEL repository if needed
    if ! rpm -q epel-release >/dev/null 2>&1; then
        yum install -y epel-release
    fi
    
    # Install OpenVPN and utilities
    yum install -y openvpn curl traceroute bind-utils
    
    echo "[OK] Packages installed"
}

setup_config() {
    local config_file="$1"
    local filename=$(basename "$config_file")
    local target_file
    
    # Determine target location
    if [[ -n "${SUDO_USER:-}" ]]; then
        local user_home=$(eval echo "~$SUDO_USER")
        target_file="$user_home/$filename"
        cp "$config_file" "$target_file"
        chown "$SUDO_USER:$SUDO_USER" "$target_file"
    else
        target_file="/root/$filename"
        cp "$config_file" "$target_file"
    fi
    
    chmod 600 "$target_file"
    echo "[OK] Config copied to: $target_file"
}

# --- Main Script ---

# Root check
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Must run as root"
    exit 1
fi

# System checks
if ! yum repolist enabled >/dev/null 2>&1; then
    echo "[ERROR] YUM not working"
    exit 1
fi

if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo "[ERROR] No internet connection"
    exit 1
fi

# Install packages
install_packages

# Handle config file if provided
if [[ $# -ge 1 ]]; then
    CONFIG_FILE="$1"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "[ERROR] Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    setup_config "$CONFIG_FILE"
fi

echo "[SUCCESS] OpenVPN client setup complete"