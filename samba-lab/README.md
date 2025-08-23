# Samba Lab

1. On VM, login as root and connect to the internet.
2. Note down the server's IP address using `ifconfig ens33 | awk '/inet / {print $2}'`.
3. On Windows:
   1. Open Command Prompt **as administrator**.
   2. Run `notepad "C:\Windows\System32\drivers\etc\hosts"` and add the following entry to the file that opens:
      ```
      <SERVER_IP> server1.example.com centos
      ```
      Replace `<SERVER_IP>` with the IP obtained in step 2.
   3. Save file with `CTRL + S` then close notepad.
4. On VM, run:
   ```bash
   curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/samba-lab/server.sh | sh
   ```
5. On Windows, verify that the correct folders were created. Press `WIN + R` then enter `\\centos`. You should see two folders: Anonymous, Secure.

> [!NOTE]
The login details for `Secure` are username `rasho` and password `linux5000`. If you had previously created `rasho`, your login details are unchanged.

> [!WARNING]
When logging into `Secure` folder, do **not** tick `Save Credentials`.

## Verification

- [ ] In Windows, you should be able to create a file in `Anonymous` without login. 
- [ ] The newly created file should appear in `/samba/anonymous`.
- [ ] You should be prompted for login details when attempting to access `Secure`. 
- [ ] In Windows, you should be able to create a file in `Secure` after login. 
- [ ] The newly created file should appear in `/home/secure`.
- [ ] Everything still works after you restart your VM. 

> [!NOTE]
Windows remembers the credentials you used for a Samba share until you log off or reboot. To test authentication again without restarting, you need to clear the cached network session. You can do that with the net use command in Windows command prompt: `net use * /delete`.