#!/bin/bash

#--------------------------------------------------------------
# Script Name: Setup NFS Server on CentOS 7.9
# Description: Installs and configures NFS server on a 
#              CentOS 7.9 machine. Handles rpcbind socket,
#              firewall, SELinux settings, and mounts local share.
# Usage: Run the script as root using bash nfs-server.sh
# Version: 0.0
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - CentOS 7.9.2009 with root privileges
# - Internet connectivity for package installation and updates
#--------------------------------------------------------------

set -ex  # Exit on error, print commands

# Retrieve client IP
CLIENT_IP="$1"

if [[ -z "$CLIENT_IP" ]]; then
    read -rp "Enter the client IP address or subnet (e.g., 192.168.1.50 or 192.168.1.0/24): " CLIENT_IP < /dev/tty
fi

if [[ -z "$CLIENT_IP" ]]; then
    echo "Client IP cannot be empty. Exiting."
    exit 1
fi

# Check if YUM is working
if yum repolist enabled >/dev/null 2>&1 && yum makecache fast >/dev/null 2>&1; then
    echo "YUM OK"
else
    echo "YUM is not setup properly. Run yum.sh. Exiting."
    exit 1
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
echo "Installing NFS packages..."
yum -y install nfs-utils rpcbind

# Verify installation
for pkg in nfs-utils rpcbind; do
    rpm -q "$pkg" >/dev/null 2>&1 || {
        echo "Package $pkg failed to install. Exiting."
        exit 1
    }
done

# --- Enable + start services ---
systemctl enable rpcbind nfs-server nfs-lock nfs-idmap
systemctl start rpcbind nfs-server nfs-lock nfs-idmap

# --- Firewalld rules ---
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=nfs
    firewall-cmd --permanent --add-service=mountd
    firewall-cmd --permanent --add-service=rpc-bind
    firewall-cmd --reload
fi

# --- SELinux config for NFS ---
if selinuxenabled; then
    setsebool -P nfs_export_all_rw 1
    setsebool -P nfs_export_all_ro 1
fi

# --- Create share directory ---
SHARE_DIR="/nfsshare"
mkdir -p "$SHARE_DIR"
chmod 777 "$SHARE_DIR"
echo "This is a test file from server to verify NFS." > "$SHARE_DIR/nfstest.txt"

# --- Detect server IP ---
SERVER_IP=$(hostname -I | awk '{for (i=1;i<=NF;i++) if ($i !~ /^127\./) {print $i; exit}}')
if [[ -z "$SERVER_IP" ]]; then
    echo "No valid IP found."
    exit 1
fi
echo "Using server IP: $SERVER_IP"

# --- Backup exports ---
if [[ -f /etc/exports ]]; then
    cp /etc/exports /etc/exports.backup.$(date +%F-%T)
fi

# --- Configure exports ---
cat <<EOL > /etc/exports
$SHARE_DIR $CLIENT_IP(rw,sync,no_root_squash)
EOL

# --- Apply exports ---
exportfs -r
systemctl restart nfs-server

# --- Show exports ---
sleep 2
showmount -e "$SERVER_IP" || echo "Warning: showmount failed, continuing..."