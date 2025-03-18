#!/bin/bash

# Define backup directory
BACKUP_DIR="/var/backups/mail_server"
DATE=$(date +"%Y%m%d%H%M")

# Create the backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Define the files to back up
FILES=(
    "/etc/hosts"
    "/etc/postfix/main.cf"
    "/etc/postfix/master.cf"
    "/etc/dovecot/conf.d/10-master.conf"
    "/etc/dovecot/conf.d/10-auth.conf"
    "/etc/dovecot/conf.d/10-mail.conf"
    "/etc/dovecot/conf.d/20-pop3.conf"
)

# Loop through the files and copy them to the backup directory with a timestamp
for FILE in "${FILES[@]}"; do
    if [ -f "$FILE" ]; then
        cp "$FILE" "$BACKUP_DIR/$(basename $FILE).$DATE"
        echo "Backed up $FILE to $BACKUP_DIR/$(basename $FILE).$DATE"
    else
        echo "File $FILE does not exist, skipping."
    fi
done

echo "Backup completed."
