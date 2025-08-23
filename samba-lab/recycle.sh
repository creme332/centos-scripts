#!/bin/bash

#--------------------------------------------------------------
# Script Name: Samba Recycle Bin Setup
# Description: Configures a Recycle Bin for an existing Samba
#              share (Secure) using the vfs_recycle module. Ensures
#              proper ownership and permissions. Designed to be
#              idempotent and safe to run multiple times.
# Version: 0.0
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - CentOS 7 with root privileges
# - Samba already installed and configured
# - Secure share (/home/secure) must already exist
#--------------------------------------------------------------
# Features:
# - Adds vfs_recycle configuration to the Secure share in smb.conf
#   if not already present
# - Sets up per-user recycle folders under /home/secure/.recycle/%U
# - Preserves directory structure of deleted files (keeptree)
#--------------------------------------------------------------
# Notes:
# - This setup does NOT include automatic cleanup of the recycle bin.
#   Files will remain until manually deleted.
# - Requires Samba service reload to apply configuration changes
# - Assumes the 'Secure' share is already restricted to group 'smbgrp'
#--------------------------------------------------------------

SMB_CONF="/etc/samba/smb.conf"
RECYCLE_DIR="/home/secure/.recycle"

# --- Ensure [Secure] share exists ---
if ! grep -q "^\[Secure\]" "$SMB_CONF"; then
    echo "Error: [Secure] share not found in $SMB_CONF"
    exit 1
fi

# --- Check if recycle configuration already exists ---
if ! grep -q "vfs objects.*recycle" "$SMB_CONF"; then
    echo "Adding Recycle Bin configuration to [Secure] share..."
    # Use awk to insert after [Secure] share definition
    awk -v RS= -v ORS="\n\n" '
    /\[Secure\]/ {
        if ($0 !~ /vfs objects/) {
            $0 = $0 "\n   vfs objects = recycle\n   recycle:repository = .recycle/%U\n   recycle:keeptree = yes\n   recycle:versions = yes\n   recycle:touch = yes\n   recycle:directory_mode = 0770\n   recycle:subdir_mode = 0700\n   recycle:exclude = *.tmp, *.temp, *.o, *.obj, ~*"
        }
    }
    { print }
    ' "$SMB_CONF" > "${SMB_CONF}.tmp" && mv "${SMB_CONF}.tmp" "$SMB_CONF"
    echo "Recycle Bin configuration added."
else
    echo "Recycle Bin already configured. Skipping smb.conf modification."
fi

# --- Ensure recycle folder exists with proper ownership and permissions ---
mkdir -p "$RECYCLE_DIR"
chown -R rasho:smbgrp "$RECYCLE_DIR"
chmod -R 0770 "$RECYCLE_DIR"

# --- Reload Samba to apply changes ---
systemctl reload smb.service nmb.service
echo "Samba reloaded. Recycle Bin setup complete."
