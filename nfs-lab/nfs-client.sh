#!/bin/bash

#--------------------------------------------------------------
# Script Name: Setup NFS Client on CentOS 7.9
# Description: Installs and configures NFS client on a 
#              CentOS 7.9 machine.
# Usage: Run the script as root using bash nfs-client.sh
# Version: 0.0
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - CentOS 7.9.2009 with root privileges
# - Internet connectivity for package installation and updates
#--------------------------------------------------------------

set -ex  # Exit on error, print commands

# --- YUM check ---
# Check if YUM is working
if yum repolist enabled >/dev/null 2>&1 && yum makecache fast >/dev/null 2>&1; then
    echo "YUM OK"
else
    echo "Setting up YUM..." >&2
    curl -fsSL https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/yum.sh -o /tmp/yum.sh && \
    bash /tmp/yum.sh || {
        echo "Failed to set up YUM. Exiting."
        exit 1
    }

    # Re-check YUM after setup
    if yum repolist enabled >/dev/null 2>&1 && yum makecache fast >/dev/null 2>&1; then
        echo "YUM fixed and working."
    else
        echo "YUM setup failed. Exiting."
        exit 1
    fi
fi

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# --- Internet check ---
if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo "Internet is available."
else
    echo "No internet connection. Exiting."
    exit 1
fi

# --- Install packages ---
echo "Installing NFS client packages..."
yum -y install nfs-utils rpcbind

# Verify installation
for pkg in nfs-utils rpcbind; do
    rpm -q "$pkg" >/dev/null 2>&1 || {
        echo "Package $pkg failed to install. Exiting."
        exit 1
    }
done

# --- Enable + start client services ---
systemctl enable rpcbind nfs-lock nfs-idmap
systemctl start rpcbind nfs-lock nfs-idmap

# --- Prompt for server details ---
read -rp "Enter the NFS server IP address: " SERVER_IP
[[ -z "$SERVER_IP" ]] && { echo "Server IP cannot be empty. Exiting."; exit 1; }

SHARE_DIR="/nfsshare"

# --- Show exports ---
showmount -e "$SERVER_IP" || echo "Warning: showmount failed, continuing..."

# --- Mount locally ---
MOUNT_POINT="/mnt/nfsshare"
mkdir -p "$MOUNT_POINT"
mount -t nfs "$SERVER_IP:$SHARE_DIR" "$MOUNT_POINT"

# Add to fstab
grep -q "^[[:space:]]*$SERVER_IP:$SHARE_DIR[[:space:]]" /etc/fstab || \
echo "$SERVER_IP:$SHARE_DIR $MOUNT_POINT nfs defaults,nofail,_netdev 0 0" >> /etc/fstab

# --- Test mount ---
if mountpoint -q "$MOUNT_POINT"; then
    echo "Local NFS mount successful!"
    ls -l "$MOUNT_POINT"
    cat "$MOUNT_POINT/nfstest.txt" || echo "Test file not found."
else
    echo "Local NFS mount failed."
    exit 1
fi
