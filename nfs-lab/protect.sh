#--------------------------------------------------------------
# Script Name : protect.sh
# Description : Create NFS shared directories with proper permissions
#               for public and private access.
# Usage       : bash protect.sh
# Version     : 0.0
# Author      : creme332
#--------------------------------------------------------------
# Requirements:
# - CentOS 7.9.2009 or compatible
# - Must be run with root privileges
#--------------------------------------------------------------

set -euo pipefail

mkdir -p /nfsshare/public
mkdir -p /nfsshare/private

# Public folder: accessible by everyone
chmod 777 /nfsshare/public

# Private folder: accessible only to superusers group
if ! getent group superusers >/dev/null; then
    groupadd -g 2000 superusers
fi
chown root:superusers /nfsshare/private
chmod 770 /nfsshare/private