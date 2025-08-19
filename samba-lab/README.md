# Samba Lab

1. On VM, login as root and connect to the internet.
2. Note down the server's IP address using `ifconfig ens33 | awk '/inet / {print $2}'`.
3. Run `hostnamectl set-hostname server1.example.com` to change the hostname of the server.
4. On Windows, add the following entry to `C:\\Windows\System32\drivers\etc\hosts`:
   ```
   <SERVER_IP> server1.example.com centos
   ```
   Replace `<SERVER_IP>` with the IP obtained in step 2.
5. On VM, run:
   ```bash
   curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/samba/samba-lab/server.sh | sh
   ```
6. Enable Network Discovery on your Windows machine:
   - Open Control Panel > Network and Sharing Center > Change advanced sharing settings.
   - Under your current network profile (Private or Public):
     - Turn on Network discovery.
     - Turn on File and printer sharing.
   - Save changes.
7. On Windows, verify that the correct folders were created in `File Explorer > Network > CENTOS`.
8. Restart your VM and check if everything still works. 
