#!/bin/bash

#--------------------------------------------------------------
# Script Name: Setup Yum on CentOS 7
# Description: Updates repository urls so that Yum can keep functioning
#              despite CentOS being discontinued. You can run the script
#              using bash yum.sh
# Version: 0.5
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - x86_64 architecture
# - CentOS:7.9.2009 with sudo privileges
# - Internet connectivity for package installation
#--------------------------------------------------------------

set -euo pipefail  # Safer: exit on error, undefined vars, fail on pipe errors
set -x             # Print commands

# Ensure that user is logged in as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# Ping Google DNS with a timeout of 3 seconds, only 1 packet
if ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then
    echo "Internet is available."
else
    echo "No internet connection. Exiting."
    exit 1
fi

# Backup configuration files
cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup.$(date +%F-%T)
cp /etc/yum.repos.d/CentOS-SCLo-scl.repo /etc/yum.repos.d/CentOS-SCLo-scl.repo.backup.$(date +%F-%T)
cp /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo.backup.$(date +%F-%T)

# Write the new content to CentOS-Base.repo
cat <<EOL > /etc/yum.repos.d/CentOS-Base.repo
[base]
name=CentOS-\$releasever - Base
baseurl=https://vault.centos.org/7.9.2009/os/x86_64
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-\$releasever - Updates
baseurl=https://vault.centos.org/7.9.2009/updates/x86_64
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-\$releasever - Extras
baseurl=https://vault.centos.org/7.9.2009/extras/x86_64
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[centosplus]
name=CentOS-\$releasever - Plus
baseurl=https://vault.centos.org/7.9.2009/centosplus/x86_64
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOL

# Fix CentOS-SCLo-sclo.repo
cat <<EOL > /etc/yum.repos.d/CentOS-SCLo-scl.repo
[centos-sclo-sclo]
name=CentOS-7 - SCLo sclo
baseurl=https://vault.centos.org/7.9.2009/sclo/x86_64/sclo/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo

[centos-sclo-sclo-testing]
name=CentOS-7 - SCLo sclo Testing
enabled=0

[centos-sclo-sclo-source]
name=CentOS-7 - SCLo sclo Sources
enabled=0

[centos-sclo-sclo-debuginfo]
name=CentOS-7 - SCLo sclo Debuginfo
enabled=0
EOL

# Fix CentOS-SCLo-scl-rh.repo
cat <<EOL > /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo
[centos-sclo-rh]
name=CentOS-7 - SCLo rh
baseurl=https://vault.centos.org/7.9.2009/sclo/x86_64/rh/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo

[centos-sclo-rh-testing]
name=CentOS-7 - SCLo rh Testing
enabled=0

[centos-sclo-rh-source]
name=CentOS-7 - SCLo rh Sources
enabled=0

[centos-sclo-rh-debuginfo]
name=CentOS-7 - SCLo rh Debuginfo
enabled=0
EOL

# Kill any process locking yum
echo "Checking for processes holding yum lock..."
YUM_LOCK_FILE="/var/run/yum.pid"

if [[ -f "$YUM_LOCK_FILE" ]]; then
    YUM_PID=$(cat "$YUM_LOCK_FILE")
    if ps -p "$YUM_PID" > /dev/null 2>&1; then
        echo "Killing process $YUM_PID holding yum lock..."
        kill -9 "$YUM_PID"
    fi
fi

for PROC in yum dnf packagekitd packagekit; do
    if pgrep -x "$PROC" > /dev/null; then
        echo "Killing $PROC processes..."
        pkill -9 "$PROC"
    fi
done

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

# Verify that Yum sees enabled repositories
REPO_COUNT=$(yum repolist enabled | awk '/repolist:/{print $2}' | tr -d ',')

if [[ -z "$REPO_COUNT" || "$REPO_COUNT" -eq 0 ]]; then
    echo "Error: No enabled Yum repositories found. Yum will not work!"
    exit 1
else
    echo "Yum is configured correctly. Enabled repositories: $REPO_COUNT"
fi