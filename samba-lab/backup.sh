#!/bin/bash
#--------------------------------------------------------------
# Script Name: Samba Automatic Backup Setup
# Description: Configures daily automatic backups for Samba shares
#              /samba/anonymous and /home/secure. Backups are
#              stored in /backup/samba/<date> and cron is used
#              to schedule daily execution. Idempotent.
# Version: 0.0
# Author: creme332
#--------------------------------------------------------------

BACKUP_DIR="/backup/samba"
ANONYMOUS_SHARE="/samba/anonymous"
SECURE_SHARE="/home/secure"
CRON_FILE="/etc/cron.daily/samba-backup"

# --- Install packages ---
yum install -y rsync cronie

# --- Enable cron ---
systemctl enable crond
systemctl start crond

# --- Ensure backup directory exists ---
mkdir -p "$BACKUP_DIR"
chown root:root "$BACKUP_DIR"
chmod 0755 "$BACKUP_DIR"

# --- Create backup script ---
cat <<'EOF' > "$CRON_FILE"
#!/bin/bash
DATE=$(date +%F)
BACKUP_DIR="/backup/samba/$DATE"

mkdir -p "$BACKUP_DIR"

# Backup anonymous share
rsync -a --delete /samba/anonymous/ "$BACKUP_DIR/anonymous/"

# Backup secure share
rsync -a --delete /home/secure/ "$BACKUP_DIR/secure/"

# Optional: keep last 7 backups only
find /backup/samba/* -maxdepth 0 -type d -mtime +7 -exec rm -rf {} \;
EOF

chmod +x "$CRON_FILE"

echo "Samba automatic backup script created at $CRON_FILE"
echo "Backups will run daily via cron and stored under $BACKUP_DIR/<date>"
