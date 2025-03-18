#!/bin/bash

#--------------------------------------------------------------
# Script Name: Setup Mail Server on CentOS 7
# Description: Automates the installation and configuration of  
#              a mail server using Postfix and Dovecot on CentOS 7.
# Version: 0.0
# Date: 2025-03-18
#--------------------------------------------------------------
# Requirements:
# - CentOS 7 with sudo privileges
# - Internet connectivity for package installation
# - Network interface 'ens33' should be present
#--------------------------------------------------------------
# Features:
# - Sets up hostname and updates /etc/hosts
# - Installs Postfix and Dovecot
# - Configures Postfix for SMTP with SSL encryption
# - Configures Dovecot for POP3/IMAP
# - Opens necessary firewall ports
# - Creates a test user for mail access
#--------------------------------------------------------------

# Define variables for server name and domain name
SERVER_NAME="mail"
DOMAIN_NAME="csft.mu"

SERVER_FQN="$SERVER_NAME.$DOMAIN_NAME"

# Set mail server's IP address to machine's IP address
IP_ADDRESS="$(ip addr show ens33 | awk '/inet / {print $2}' | cut -d'/' -f1)"

# Step 1 & 2: Set hostname and update hosts file
echo "Setting hostname..."
hostnamectl set-hostname $SERVER_FQN
echo "$IP_ADDRESS $SERVER_FQN" >> /etc/hosts

# Step 3: Install required packages
echo "Installing Postfix and Dovecot..."
yum -y install postfix dovecot

# Step 4: Create SSL certificate for encryption
mkdir -p /etc/postfix/ssl
cd /etc/postfix/ssl
openssl genrsa -des3 -out server.key 2048
openssl rsa -in server.key -out server.key.insecure
mv server.key server.key.secure
mv server.key.insecure server.key
openssl req -new -key server.key -out server.csr
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

# Step 5.1: Uncomment lines regarding inet_interfaces and my_destination
sed -i 's/#inet_interfaces = localhost/inet_interfaces = localhost/' /etc/postfix/main.cf
sed -i 's/#mydestination = \$myhostname, localhost.\$mydomain, localhost/mydestination = \$myhostname, localhost.\$mydomain, localhost/' /etc/postfix/main.cf

# Step 5.2: Update Postfix main configuration
cat <<EOL >> /etc/postfix/main.cf
myhostname = $SERVER_FQN
mydomain = $DOMAIN_NAME
myorigin = \$mydomain
home_mailbox = mail/
mynetworks = 127.0.0.0/8
inet_interfaces = all
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_local_domain =
smtpd_sasl_security_options = noanonymous
broken_sasl_auth_clients = yes
smtpd_sasl_auth_enable = yes
smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination
smtp_tls_security_level = may
smtpd_tls_security_level = may
smtp_tls_note_starttls_offer = yes
smtpd_tls_loglevel = 1
smtpd_tls_key_file = /etc/postfix/ssl/server.key
smtpd_tls_cert_file = /etc/postfix/ssl/server.crt
smtpd_tls_received_header = yes
smtpd_tls_session_cache_timeout = 3600s
tls_random_source = dev:/dev/urandom
EOL

# Step 6: Update master.cf
# TODO: Check if submission inet n - n - - smtpd is already present in file
sed -i '/smtp inet n - n - - smtpd/a \
submission inet n - n - - smtpd\n\
-o syslog_name=postfix/submission\n\
-o smtpd_sasl_auth_enable=yes\n\
-o smtpd_recipient_restrictions=permit_sasl_authenticated,reject\n\
-o milter_macro_daemon_name=ORIGINATING\n\
smtps inet n - n - - smtpd\n\
-o syslog_name=postfix/smtps\n\
-o smtpd_sasl_auth_enable=yes\n\
-o smtpd_recipient_restrictions=permit_sasl_authenticated,reject\n\
-o milter_macro_daemon_name=ORIGINATING' /etc/postfix/master.cf

# Step 7: Configure Dovecot for SMTP Auth
# TODO: Check if there is a space between # and Postfix
sed -i '/#Postfix smtp-auth/a \
unix_listener /var/spool/postfix/private/auth {\n  mode = 0660\n  user = postfix\n  group = postfix\n}' /etc/dovecot/conf.d/10-master.conf

# Step 8
sed -i 's/auth_mechanisms = plain/auth_mechanisms = plain login/' /etc/dovecot/conf.d/10-auth.conf

# Step 9: Restart and enable services
systemctl restart postfix
systemctl enable postfix
systemctl restart dovecot
systemctl enable dovecot

# Step 10: Add the firewall rules to allow 25, 587 and 465 ports
firewall-cmd --permanent --add-service=smtp
firewall-cmd --permanent --add-port=587/tcp
firewall-cmd --permanent --add-port=465/tcp
firewall-cmd --reload

# Step 11: Set mail location in dovecot
sed -i 's/#mail_location = /mail_location = maildir:~\/mail/' /etc/dovecot/conf.d/10-mail.conf

# Step 12: Uncomment line with pop3_uidl_format
sed -i 's/#pop3_uidl_format = %08Xu%08Xv/pop3_uidl_format = %08Xu%08Xv/' /etc/dovecot/conf.d/20-pop3.conf

# Step 13: Restart dovecot service
systemctl restart dovecot

# Step 14: Add firewall rules to allow 110, 143, 993 and 995
firewall-cmd --permanent --add-port=110/tcp
firewall-cmd --permanent --add-service=pop3s
firewall-cmd --permanent --add-port=143/tcp
firewall-cmd --permanent --add-service=imaps
firewall-cmd --reload

# Step 15: Create user for testing
echo "Creating user john for testing..."
useradd -m john -s /sbin/nologin
passwd john

echo "Mail server setup complete."

# Final checkups
# run postfix check
# check connectivity telnet