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

# Get IP address (adjust interface as needed)
IP_ADDRESS=$(ip -4 addr show scope global | awk '/inet /{print $2}' | cut -d/ -f1 | head -n 1)

if [ -z "$IP_ADDRESS" ]; then
    echo "Could not determine IP address. Exiting."
    exit 1
fi

echo "Server IP address detected as: $IP_ADDRESS"

# Install packages
echo "Installing packages..."
yum -y install nfs-utils nfs-utils-lib portmap

# Verify that packages were installed successfully
for pkg in nfs-utils portmap; do
    if rpm -q $pkg > /dev/null 2>&1; then
        echo "Package $pkg is installed."
    else
        echo "Package $pkg failed to install. Exiting."
        exit 1
    fi
done

# Start services
echo "Starting services..."
/etc/init.d/portmap start
/etc/init.d/nfs start
chkconfig --level 35 portmap on
chkconfig --level 35 nfs on

# Create NFS share directory if it does not exist
SHARE_DIR="/nfsshare"
if [ ! -d "$SHARE_DIR" ]; then
    mkdir -p "$SHARE_DIR"
fi

# Create test file in share directory
cat <<EOL > "$SHARE_DIR/nfstest.txt"
This is a test file to verify the NFS server setup.
EOL

# Make a copy of /etc/exports
mv /etc/exports /etc/exports.backup.$(date +%F-%T)

# Export directory for client IP or subnet
cat <<EOL > /etc/exports
$SHARE_DIR $IP_ADDRESS(rw,sync,no_root_squash)
EOL

# !Export shares
#exportfs -r

# !For CentOS 6 with portmap, no systemctl restart is needed but you can restart services
#/etc/init.d/nfs restart
#/etc/init.d/portmap restart

# Show exported shares
showmount -e

# Create mount point for local testing
MOUNT_POINT="/mnt/nfsshare"
if [ ! -d "$MOUNT_POINT" ]; then
    mkdir -p "$MOUNT_POINT"
fi

# Mount the NFS share locally
mount -t nfs $IP_ADDRESS:$SHARE_DIR $MOUNT_POINT

# Make a copy of /etc/fstab
mv /etc/fstab /etc/fstab.backup.$(date +%F-%T)

# Add to /etc/fstab for persistence if not already present
grep -q "^$IP_ADDRESS:$SHARE_DIR" /etc/fstab || echo "$IP_ADDRESS:$SHARE_DIR $MOUNT_POINT nfs defaults 0 0" >> /etc/fstab

# Verify mount success
if mountpoint -q $MOUNT_POINT; then
    echo "Mount successful. Listing contents:"
    ls "$MOUNT_POINT"
    cat "$MOUNT_POINT/nfstest.txt"
else
    echo "Mount failed."
fi