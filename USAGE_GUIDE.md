1. Ensure that you are connected to the wired Ethernet network. If connected, you should see your IP address with `ifconfig ens33`.
2. Open 2 terminals, one for Thunderbird and one for main terminal.

# Normal Lab

Show that emails can be exchanged normally.

# Email backup

```bash
crontab -e
cd /backup/email
ls
tar -xvzf archive.tar.gz
```

Show extraction

# Spam detection

```
crontab -e
spamassassin -t < test-email.eml

```

Show spam being blocked

# Thunderbird

To open Thunderbird:

```bash
thunderbird
```

To see mail settings for a user:

```bash
doveadm user john
```

To view available virtual users (users with no login shell):

```bash
awk -F: '$7 ~ /(nologin|false)/ {print $1}' /etc/passwd
```