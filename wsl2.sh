#!/bin/bash

#--------------------------------------------------------------
# Script Name: Setup Yum on CentOS 7 for WSL2
# Description: 
#   - Updates CentOS 7 YUM repositories to point to the CentOS Vault
#     (since CentOS 7 is EOL).
#   - Adds Google DNS servers for reliable name resolution.
#   - Updates and installs additional common utilities.
#   - Configures WSL2 to use systemd and preserve custom DNS settings.
#
# Usage:
#   sudo bash wsl2.sh
#
# Version: 0.1
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - WSL2
# - CentOS 7.9.2009 root/sudo access
# - Internet connectivity
#--------------------------------------------------------------

set -euo pipefail  # Exit on error, undefined vars, fail on pipe errors
set -x             # Print commands

# Ensure that user is logged in as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# Detect if running in WSL2
if ! grep -qi microsoft /proc/version && grep -qi wsl2 /proc/version; then
    echo "Not running in WSL2."
fi

# Ping Google DNS with a timeout of 3 seconds, only 1 packet
if ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then
    echo "Internet is available."
else
    echo "No internet connection. Exiting."
    exit 1
fi

# Backup the original CentOS-Base.repo file before modifying
cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup.$(date +%F-%T)

# Write the new content to CentOS-Base.repo
cat <<EOL > /etc/yum.repos.d/CentOS-Base.repo
[base]
name=CentOS-\$releasever - Base
baseurl=https://vault.centos.org/7.9.2009/os/\$basearch
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#released updates
[updates]
name=CentOS-\$releasever - Updates
baseurl=https://vault.centos.org/7.9.2009/updates/\$basearch
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-\$releasever - Extras
baseurl=https://vault.centos.org/7.9.2009/extras/\$basearch
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-\$releasever - Plus
baseurl=https://vault.centos.org/7.9.2009/centosplus/\$basearch
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOL

# Clear the yum cache to ensure it fetches the latest repository metadata
yum clean all
yum makecache

# Add Google's DNS servers to resolv.conf
RESOLV_CONF="/etc/resolv.conf"

GOOGLE_DNS1="nameserver 8.8.8.8"
GOOGLE_DNS2="nameserver 8.8.4.4"

# Backup existing resolv.conf
cp $RESOLV_CONF ${RESOLV_CONF}.backup.$(date +%F-%T)

# Add Google's DNS servers if not already present
if ! grep -q "$GOOGLE_DNS1" $RESOLV_CONF; then
    echo "$GOOGLE_DNS1" >> $RESOLV_CONF
fi

if ! grep -q "$GOOGLE_DNS2" $RESOLV_CONF; then
    echo "$GOOGLE_DNS2" >> $RESOLV_CONF
fi

# Update system
yum update -y

# Install additional packages which do not come by default
yum install -y epel-release net-tools firewalld sudo which policycoreutils wget curl vim

# Create configuration file
cat <<EOL > /etc/wsl.conf
[boot]
systemd=true

[network]
generateHosts = false
generateResolvConf = false  
EOL

echo "Setup complete. Restart WSL2."