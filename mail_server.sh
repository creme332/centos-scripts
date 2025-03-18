#!/bin/bash

# Variables
HOSTNAME="mail.csft.mu"
IP_ADDRESS="172.27.0.51"
USER_NAME="john"

# Step 1: Set hostname and update hosts file
echo "Setting hostname..."
hostnamectl set-hostname $HOSTNAME
echo "$IP_ADDRESS $HOSTNAME" >> /etc/hosts

# Step 2: Install required packages
echo "Installing Postfix and Dovecot..."
yum -y install postfix dovecot

# Step 3: Configure Postfix
mkdir -p /etc/postfix/ssl
cd /etc/postfix/ssl
openssl genrsa -des3 -out server.key 2048
openssl rsa -in server.key -out server.key.insecure
mv server.key server.key.secure
mv server.key.insecure server.key
openssl req -new -key server.key -out server.csr
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

# Update Postfix main configuration
cat <<EOL >> /etc/postfix/main.cf
myhostname = $HOSTNAME
mydomain = csft.mu
myorigin = \$mydomain
home_mailbox = mail/
mynetworks = 127.0.0.0/8
inet_interfaces = all
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination
smtp_tls_security_level = may
smtpd_tls_security_level = may
smtpd_tls_key_file = /etc/postfix/ssl/server.key
smtpd_tls_cert_file = /etc/postfix/ssl/server.crt
EOL

# Update master.cf
cat <<EOL >> /etc/postfix/master.cf
submission inet n - n - - smtpd
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
smtps inet n - n - - smtpd
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
EOL

# Configure Dovecot for SMTP Auth
sed -i '/# Postfix smtp-auth/a \
unix_listener /var/spool/postfix/private/auth {\n  mode = 0660\n  user = postfix\n  group = postfix\n}' /etc/dovecot/conf.d/10-master.conf

sed -i 's/auth_mechanisms = plain/auth_mechanisms = plain login/' /etc/dovecot/conf.d/10-auth.conf

# Restart and enable services
systemctl restart postfix
enable postfix
systemctl restart dovecot
enable dovecot

# Open firewall ports
firewall-cmd --permanent --add-service=smtp
firewall-cmd --permanent --add-port=587/tcp
firewall-cmd --permanent --add-port=465/tcp
firewall-cmd --permanent --add-port=110/tcp
firewall-cmd --permanent --add-service=pop3s
firewall-cmd --permanent --add-port=143/tcp
firewall-cmd --permanent --add-service=imaps
firewall-cmd --reload

# Create user for testing
useradd -m $USER_NAME -s /sbin/nologin
passwd $USER_NAME

echo "Mail server setup complete."

