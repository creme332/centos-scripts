#!/bin/bash

#-------------------------------------------------------------- 
# Script Name: OpenVPN Client Setup for CentOS 7
# Description: Minimal setup - installs packages only
# Usage: bash client.sh
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
    yum install -y openvpn curl traceroute bind-utils openssh-clients
    
    echo "[OK] Packages installed"
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

# Download the verification script and give permission
curl -o /usr/local/bin/vpn-verify https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/vpn-lab/vpn-verify
chmod +x /usr/local/bin/vpn-verify

echo "[SUCCESS] OpenVPN client setup complete"