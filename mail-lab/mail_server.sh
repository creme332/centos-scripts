#!/bin/bash

#--------------------------------------------------------------
# Script Name: Setup Mail Server on CentOS 7
# Description: Automates the installation and configuration of  
#              a mail server using Postfix and Dovecot on CentOS 7.
# Version: 0.2
# Author: creme332
#--------------------------------------------------------------
# Requirements:
# - CentOS 7 with sudo privileges
# - Internet connectivity for package installation
# - Network interface 'ens33' should be present
# - Packages: net-tools, firewalld
#--------------------------------------------------------------
# Features:
# - Sets up hostname and updates /etc/hosts
# - Installs Postfix, Dovecot, Telnet, Thunderbird
# - Configures Postfix for SMTP with SSL encryption
# - Configures Dovecot for POP3/IMAP
# - Opens necessary firewall ports
# - Creates virtual users for mail access
#--------------------------------------------------------------

set -ex  # Exit on error, print commands

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

# Check if YUM is working
if yum repolist enabled >/dev/null 2>&1 && yum makecache fast >/dev/null 2>&1; then
    echo "YUM OK"
else
    echo "YUM is not setup properly. Run yum.sh. Exiting."
    exit 1
fi

# Function to check if a package is installed
is_installed() {
    rpm -q "$1" &>/dev/null
}

# Function to reinstall a package (reset configurations)
reset_package() {
    local package=$1
    echo "Resetting $package to default settings..."
    yum -y remove "$package"  # Remove package
    yum -y install "$package"  # Reinstall package
}

# Function to install a package if not installed
install_package() {
    local package=$1
    echo "Installing $package..."
    yum -y install "$package"
}

# Define variables for server name and domain name
SERVER_NAME="mail"
DOMAIN_NAME="csft.mu"

SERVER_FQN="$SERVER_NAME.$DOMAIN_NAME"

# Set mail server's IP address to machine's IP address
IP_ADDRESS="$(ifconfig ens33 | awk '/inet / {print $2}' | cut -d'/' -f1)"

# Step 1 & 2: Set hostname and update hosts file
hostnamectl set-hostname "$SERVER_FQN"

# Check if the entry already exists in /etc/hosts
if grep -q "$IP_ADDRESS $SERVER_FQN" /etc/hosts; then
    echo "Entry already exists in /etc/hosts. No changes made."
else
    echo "Adding $IP_ADDRESS $SERVER_FQN to /etc/hosts..."
    echo "$IP_ADDRESS $SERVER_FQN" >> /etc/hosts
    echo "Entry added successfully."
fi

# Step 3: Install required packages

# Handling Postfix
if is_installed "postfix"; then
    reset_package "postfix"
else
    install_package "postfix"
fi

# Handling Dovecot
if is_installed "dovecot"; then
    reset_package "dovecot"
else
    install_package "dovecot"
fi

install_package "telnet"

install_package "thunderbird"

# Step 4: Create SSL certificate for encryption
mkdir -p /etc/postfix/ssl
cd /etc/postfix/ssl

# Create the openssl.cnf file with hardcoded values
cat > /etc/ssl/openssl.cnf <<EOF
[req]
default_bits       = 2048
default_keyfile    = privkey.pem
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt = no        # Do not ask for any input, all fields are prefilled

[req_distinguished_name]
countryName                 = MU
stateOrProvinceName         = Moka
localityName                = Reduit
organizationName            = UOM
organizationalUnitName      = FOICDT
commonName                  = mail.csft.mu
emailAddress                = root@csft.com

[ v3_req ]

EOF

# Generate the RSA private key without a passphrase
openssl genrsa -out server.key 2048

# Generate the certificate signing request (CSR)
openssl req -new -key server.key -out server.csr -config /etc/ssl/openssl.cnf

# Generate the self-signed SSL certificate
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

# Step 5: Update Postfix main configuration
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
cat <<EOL >> /etc/postfix/master.cf

submission inet n - n - - smtpd
 -o syslog_name=postfix/submission
 -o smtpd_sasl_auth_enable=yes
 -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
 -o milter_macro_daemon_name=ORIGINATING

smtps inet n - n - - smtpd
 -o syslog_name=postfix/smtps
 -o smtpd_sasl_auth_enable=yes
 -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
 -o milter_macro_daemon_name=ORIGINATING

EOL

# Run postfix check to verify configuration
postfix check
if [ $? -eq 0 ]; then
    echo "Postfix configuration is valid!"
else
    echo "Postfix configuration has errors."
fi

# Step 7: Configure Dovecot for SMTP Auth
sed -i '/# Postfix smtp-auth/a \
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

# Step 15: Create virtual users
echo "Creating users john and tom for testing..."
useradd -m john -s /sbin/nologin
echo "john" | passwd --stdin john

useradd -m tom -s /sbin/nologin
echo "tom" | passwd --stdin tom

echo "Mail server setup complete."