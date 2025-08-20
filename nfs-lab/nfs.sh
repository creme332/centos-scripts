#!/bin/bash

#--------------------------------------------------------------
# Script Name: Setup NFS Server and Client on CentOS 7.9
# Description: Installs and configures NFS server and client on the
#              same CentOS 7.9 machine. Handles rpcbind socket,
#              firewall, SELinux settings, and mounts local share.
#              Suitable for local testing and LAN usage.
# Usage: Run the script as root using bash nfs.sh
# Version: 0.1
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - CentOS 7.9.2009 with root privileges
# - Internet connectivity for package installation and updates
#--------------------------------------------------------------

set -euo pipefail

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
echo "This is a test file to verify local NFS." > "$SHARE_DIR/nfstest.txt"

# --- Detect server IP ---
SERVER_IP=$(hostname -I | awk '{for (i=1;i<=NF;i++) if ($i !~ /^127\./) {print $i; exit}}')
if [[ -z "$SERVER_IP" ]]; then
    echo "No valid IP found. Using 127.0.0.1 for local testing."
    SERVER_IP="127.0.0.1"
fi
echo "Using server IP: $SERVER_IP"

# --- Backup exports ---
if [[ -f /etc/exports ]]; then
    cp /etc/exports /etc/exports.backup.$(date +%F-%T)
fi

# --- Configure exports ---
cat <<EOL > /etc/exports
$SHARE_DIR $SERVER_IP(rw,sync,no_root_squash)
EOL

# --- Apply exports ---
exportfs -r
systemctl restart nfs-server

# --- Show exports ---
sleep 2
showmount -e "$SERVER_IP" || echo "Warning: showmount failed, continuing..."

# --- Mount locally ---
MOUNT_POINT="/mnt/nfsshare"
mkdir -p "$MOUNT_POINT"

mount -t nfs "$SERVER_IP:$SHARE_DIR" "$MOUNT_POINT"

# Add to fstab (avoid duplicates, safe mount options)
grep -q "^$SERVER_IP:$SHARE_DIR" /etc/fstab || \
echo "$SERVER_IP:$SHARE_DIR $MOUNT_POINT nfs defaults,nofail,_netdev 0 0" >> /etc/fstab

# --- Test mount ---
if mountpoint -q "$MOUNT_POINT"; then
    echo "Local NFS mount successful!"
    ls -l "$MOUNT_POINT"
    cat "$MOUNT_POINT/nfstest.txt"
else
    echo "Local NFS mount failed."
    exit 1
fi
