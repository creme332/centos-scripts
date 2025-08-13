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