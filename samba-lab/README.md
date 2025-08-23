# Samba Lab

## Prerequisites

Your Windows machine must be able to communicate with your VM. To check if this is possible:

1. On VM, connect to the internet and note down the server's IP address using `ifconfig ens33 | awk '/inet / {print $2}'`.
2. In Windows Command Prompt, run `ping <SERVER_IP>` where `<SERVER_IP>` with the IP obtained in the previous step.
3. You should see a similar output with no packet timeout:
   ```
   Pinging 172.23.49.69 with 32 bytes of data:
   Reply from 172.23.49.69: bytes=32 time<1ms TTL=64
   Reply from 172.23.49.69: bytes=32 time<1ms TTL=64
   Reply from 172.23.49.69: bytes=32 time<1ms TTL=64
   Reply from 172.23.49.69: bytes=32 time<1ms TTL=64

   Ping statistics for 172.23.49.69:
      Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
   Approximate round trip times in milli-seconds:
      Minimum = 0ms, Maximum = 0ms, Average = 0ms
   ```

If you obtained packet timeouts, then you need to use the Bridge networking mode on your VM:

![alt text](img/vmware-player.png)

![alt text](img/vmware-network.png)

Finally, repeat the above steps to verify that your VM is accessible from Windows.

## Basic Setup

1. On your VM, login as root and connect to the internet.
2. Note down the server's IP address using `ifconfig ens33 | awk '/inet / {print $2}'`.
3. On Windows:
   1. Open Command Prompt **as administrator**.
   2. Open your host files with notepad: `notepad "C:\Windows\System32\drivers\etc\hosts"`
   3. Identify all **uncommented entries** containing `centos` as alias. If found, **delete the entry or comment it**.
   4. Add a new entry to the file:
      ```
      <SERVER_IP> server1.example.com centos
      ```
      Replace `<SERVER_IP>` with the IP obtained in step 2.
   5. Save the file with `CTRL + S` then close notepad.
4. On VM, run:
   ```bash
   curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/samba-lab/server.sh | sh
   ```
5. On Windows, verify that the correct folders were created. Press `WIN + R` then enter `\\centos`. You should see two folders: Anonymous, Secure.

> [!Important]
The login details for `Secure` are username `rasho` and password `linux5000`. If you had previously created `rasho`, your login details are unchanged.

> [!Important]
Each time you start your VM, you need to run `systemctl restart smb.service`.

> [!WARNING]
When logging into `Secure` folder, do **not** tick `Save Credentials`.

### Verification

- [ ] In Windows, you should be able to create a file in `Anonymous` without login. 
- [ ] The newly created file should appear in `/samba/anonymous`.
- [ ] You should be prompted for login details when attempting to access `Secure`. 
- [ ] In Windows, you should be able to create a file in `Secure` after login. 
- [ ] The newly created file should appear in `/home/secure`.
- [ ] Everything still works after you restart your computer. You need to restart the Samba server on the VM on startup.

> [!NOTE]
Windows remembers the credentials you used for a Samba share until you log off or reboot. To test authentication again without restarting, you need to clear the cached network session. You can do that with the net use command in Windows command prompt: `net use * /delete`. You then need to wait a few seconds **at least 10 seconds** before using `WIN + R` again.

> [!NOTE]
> If obtain an error like `\\centos\Secure is not accessible ... Multiple connections to a server or shared resource is by the user name, are not allowed...`  when accessing Secure folder, then **restart your Windows machine**.

## Extra: Recycle Bin

Samba has a Recycle Bin feature built in via the `vfs_recycle` module. That way, deleted files don't disappear immediately but go into a hidden `.recycle` directory inside the share.

To set it up:

```bash
curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/samba-lab/recycle.sh | sh
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
curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/samba-lab/backup.sh | sh
```

### Verification

Trigger a manual backup:

```bash
bash /etc/cron.daily/samba-backup
```

A backup directory should be created under `/backup/samba/<date>/`. Inside it you should see two folders: `anonymous` and `secure`.
