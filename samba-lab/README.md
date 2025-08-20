# Samba Lab

1. On VM, login as root and connect to the internet.
2. Note down the server's IP address using `ifconfig ens33 | awk '/inet / {print $2}'`.
3. Run `hostnamectl set-hostname server1.example.com` to change the hostname of the server.
4. On Windows:
   1. Open Command Prompt as administrator.
   2. Run `notepad C:\\Windows\System32\drivers\etc\hosts` and add the following entry to the file that opens:
      ```
      <SERVER_IP> server1.example.com centos
      ```
      Replace `<SERVER_IP>` with the IP obtained in step 2.
5. On VM, run:
   ```bash
   curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/samba/samba-lab/server.sh | sh
   ```
6. If Network Discovery is not enabled on Windows, enable Network Discovery on your Windows machine:
   - Open Control Panel > Network and Sharing Center > Change advanced sharing settings.
   - Under your current network profile (Private or Public):
     - Turn on Network discovery.
     - Turn on File and printer sharing.
   - Save changes.
7. On Windows, verify that the correct folders were created. Press `WIN + R` then enter `\\centos`. You should see two folders: Anonymous, Secure.
8. You should be able to create a file in `Anonymous` without login. 
9. You should be prompted for login details when attempting to access `Secure`. The login details are username `rasho` and password `linux5000`. 
    > [!WARNING]
    Do **not** tick `Save Credentials`.
10. Restart your VM and check if everything still works. 

> [!NOTE]
Windows remembers the credentials you used for a Samba share until you log off or reboot. To test authentication again without restarting, you need to clear the cached network session. You can do that with the net use command in Windows command prompt: `net use * /delete`.