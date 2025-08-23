# Samba Lab

## Basic Setup

1. On VM, login as root and connect to the internet.
2. Note down the server's IP address using `ifconfig ens33 | awk '/inet / {print $2}'`.
3. Run `hostnamectl set-hostname server1.example.com` to change the hostname of the server.
4. On Windows:
   1. Open Command Prompt **as administrator**.
   2. Run `notepad "C:\Windows\System32\drivers\etc\hosts"` and add the following entry to the file that opens:
      ```
      <SERVER_IP> server1.example.com centos
      ```
      Replace `<SERVER_IP>` with the IP obtained in step 2.
   3. Save file with `CTRL + S` then close notepad.
5. On VM, run:
   ```bash
   curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/samba-lab/server.sh | sh
   ```
6. On Windows, verify that the correct folders were created. Press `WIN + R` then enter `\\centos`. You should see two folders: Anonymous, Secure.

> [!NOTE]
The login details for `Secure` are username `rasho` and password `linux5000`. If you had previously created `rasho`, your login details are unchanged.

> [!WARNING]
When logging into `Secure` folder, do **not** tick `Save Credentials`.

### Verification

- [ ] In Windows, you should be able to create a file in `Anonymous` without login. 
- [ ] The newly created file should appear in `/samba/anonymous`.
- [ ] You should be prompted for login details when attempting to access `Secure`. 
- [ ] In Windows, you should be able to create a file in `Secure` after login. 
- [ ] The newly created file should appear in `/home/secure`.
- [ ] Everything still works after you restart your VM. 

> [!NOTE]
Windows remembers the credentials you used for a Samba share until you log off or reboot. To test authentication again without restarting, you need to clear the cached network session. You can do that with the net use command in Windows command prompt: `net use * /delete`.

## Extra: Recycle Bin

Samba has a Recycle Bin feature built in via the `vfs_recycle` module. That way, deleted files don't disappear immediately but go into a hidden `.recycle` directory inside the share.

To set it up:

```bash
curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/delete/samba-lab/recycle.sh | sh
```

### Verification Steps

1. Access `\\centos\Secure` from a Windows client.
2. Delete a file from the Secure share.
3. Check that the deleted file appears under:
   ```
      /home/secure/.recycle/<username>/
   ```
5. Verify that directory structure is preserved.
6. Confirm permissions allow the correct user and group to read/write.
7. Repeat to ensure multiple versions of files are saved correctly.

## Extra: Automatic Backup

To set it up:

```bash
curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/delete/samba-lab/backup.sh | sh
```

### Verification

Trigger a manual backup:

```bash
bash /etc/cron.daily/samba-backup
```

A backup directory should be created under `/backup/samba/<date>/`. Inside it you should see two folders: `anonymous` and `secure`.
