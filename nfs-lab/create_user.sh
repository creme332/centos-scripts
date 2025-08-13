#!/bin/bash
# Usage: sudo ./create_user_primary_only.sh username uid
# Example: sudo ./create_user_primary_only.sh alice 1001 superusers

# Root check
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 username uid primary_group"
    exit 1
fi

USERNAME="$1"
USER_UID="$2"
GID="2000"
PRIMARY_GROUP="superusers"

# Function to create a group if it does not exist
create_group() {
    local group_name="$1"
    local gid="$2"
    
    if ! getent group "$group_name" > /dev/null; then
        groupadd -g "$gid" "$group_name"
        echo "Created group $group_name with GID $gid"
    fi
}

# Create primary group
create_group "$PRIMARY_GROUP" "$GID"

# Create user with UID and primary group
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -u "$USER_UID" -g "$GID" "$USERNAME"
    echo "Created user $USERNAME with UID $USER_UID"
else
    echo "User $USERNAME already exists"
fi
