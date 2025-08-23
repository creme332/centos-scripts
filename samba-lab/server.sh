#!/bin/bash

#--------------------------------------------------------------
# Script Name: Setup Samba Server on CentOS 7
# Description: Installs and configures a Samba server with both
#              anonymous and secure shares, firewall rules, and
#              SELinux context adjustments. Designed to be idempotent,
#              so it can be run multiple times safely.
# Version: 0.1
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - CentOS 7 with root privileges
# - Internet access for package installation
# - Packages: samba, samba-client, samba-common, firewalld,
#             policycoreutils-python (for semanage)
#--------------------------------------------------------------
# Features:
# - Validates yum availability, root access, and internet connectivity
# - Installs required Samba packages
# - Creates backup of original smb.conf
# - Adds [Anonymous] and [Secure] shares only if not present
# - Configures directories with correct ownership and permissions
# - Sets persistent SELinux file contexts for shares
# - Creates group 'smbgrp' and user 'rasho' (with default password)
# - Ensures firewall allows Samba services
# - Enables and restarts Samba (smb/nmb) services
# - Idempotent: safe to run multiple times without duplicating config
#--------------------------------------------------------------

set -euo pipefail

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# --- YUM check ---
if yum repolist enabled >/dev/null 2>&1 && yum makecache fast >/dev/null 2>&1; then
    echo "YUM OK"
else
    echo "YUM is not setup properly. Run yum.sh. Exiting."
    exit 1
fi

# --- Internet check ---
if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo "No internet connection. Exiting."
    exit 1
fi

# Set hostname
TARGET_HOSTNAME="server1.example.com"
CURRENT_HOSTNAME=$(hostnamectl status --static)

if [ "$CURRENT_HOSTNAME" != "$TARGET_HOSTNAME" ]; then
    hostnamectl set-hostname "$TARGET_HOSTNAME"
    echo "Hostname changed to $TARGET_HOSTNAME"
else
    echo "Hostname is already $TARGET_HOSTNAME"
fi

# --- Install packages ---
yum install -y samba samba-client samba-common policycoreutils-python

# --- Create anonymous share directory ---
mkdir -p /samba/anonymous
chmod -R 0755 /samba/anonymous
chown -R nobody:nobody /samba/anonymous

# --- SELinux persistence for anonymous share ---
semanage fcontext -a -t samba_share_t "/samba/anonymous(/.*)?" 2>/dev/null || true
restorecon -R /samba/anonymous

# --- Ensure smbgrp group exists ---
if ! getent group smbgrp >/dev/null; then
    groupadd smbgrp
fi

# --- Ensure user rasho exists ---
if ! id rasho >/dev/null 2>&1; then
    useradd -G smbgrp rasho
else
    usermod -a -G smbgrp rasho
fi

# --- Ensure rasho has Samba password ---
if ! pdbedit -L | grep -q "^rasho:"; then
    (echo "linux5000"; echo "linux5000") | smbpasswd -s -a rasho
fi

# --- Create secure share directory ---
mkdir -p /home/secure
chown -R rasho:smbgrp /home/secure/
chmod -R 0770 /home/secure/

# --- SELinux persistence for secure share ---
semanage fcontext -a -t samba_share_t "/home/secure(/.*)?" 2>/dev/null || true
restorecon -R /home/secure

# --- Create a timestamped backup of smb.conf ---
cp /etc/samba/smb.conf "/etc/samba/smb.conf.backup.$(date +%F-%T)"

# --- Overwrite old config with new config ---
cat <<EOL > /etc/samba/smb.conf

[global]
workgroup = WORKGROUP
server string = Samba Server %v
netbios name = centos
security = user
map to guest = bad user
dns proxy = no
#========================== Share Definitions ==============================
[Anonymous]
path = /samba/anonymous
browsable = yes
writable = yes
guest ok = yes
read only = no

[Secure]
path = /home/secure
valid users = @smbgrp
guest ok = no
writable = yes
browsable = yes

# We don't want user home directories to be accessible in Windows
[homes]
browseable = no
available = no
EOL

# --- Verify Samba configuration ---
echo "Verifying Samba configuration..."
if ! testparm -s >/dev/null 2>&1; then
    echo "Samba configuration test failed. Please check /etc/samba/smb.conf"
    exit 1
fi

# --- Enable and restart services ---
systemctl enable smb.service nmb.service
systemctl restart smb.service nmb.service

# --- Firewall ---
firewall-cmd --permanent --zone=public --add-service=samba
firewall-cmd --reload

echo "Samba setup complete."