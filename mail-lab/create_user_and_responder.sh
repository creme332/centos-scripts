#!/bin/bash

set -euo pipefail

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Check if username is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME=$1
EMAIL="${USERNAME}@csft.mu"  # !TODO Change domain accordingly
USER_HOME="/home/${USERNAME}"

# Create a /sbin/nologin user
if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists."
else
    useradd -m -s /sbin/nologin "$USERNAME"
    echo "User $USERNAME created with /sbin/nologin shell."

    # Set password same as username
    echo "$USERNAME:$USERNAME" | chpasswd
    echo "Password set to '$USERNAME'."
fi

# Set up Sieve auto-responder
echo "Setting up auto-responder for $USERNAME..."

mkdir -p "${USER_HOME}/sieve"

cat <<EOL > "${USER_HOME}/sieve/vacation.sieve"
require ["vacation"];

vacation :days 1 :addresses ["$EMAIL"] :subject "Out of Office" "I am currently out of the office.";

EOL

# Compile sieve script
sievec "${USER_HOME}/sieve/vacation.sieve"

# Create symlink for Dovecot
ln -sf "${USER_HOME}/sieve/vacation.sieve" "${USER_HOME}/.dovecot.sieve"

# Set ownership and permissions
chown -R "$USERNAME:$USERNAME" "${USER_HOME}/sieve"
chmod -R 700 "${USER_HOME}/sieve"
chmod 600 "${USER_HOME}/sieve/vacation.sieve"

echo "Auto-responder setup complete for $USERNAME."