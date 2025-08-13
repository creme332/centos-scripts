
# NFS

## Different machines

1. Open 2 VMs, one for client and another one for server.
2. In both VMs:
   1. Login as root with `su -`.
   2. Connect to the internet.
   3. Note down the machine IP address using `ifconfig ens33 | awk '/inet / {print $2}'`.
3. On server VM, run the following command and replace `192.168.136.50` with the client's IP:
    ```bash
    curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/nfs-lab/nfs-server.sh | bash -s -- 192.168.136.50
    ```
4. On client VM, run `nfs-client.sh` and replace `192.168.136.100` with the client's IP:
    ```bash
    curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/nfs-lab/nfs-client.sh | bash -s -- 192.168.136.100
    ```
## Same machine

To setup an NFS client & server on the **same** machine:

```bash
curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/nfs-lab/nfs.sh | sh
```

## Authentication

Assuming you already have a shared directory `/nfsshare` which both server and client can read/write:

1. On server VM, run `protect.sh` to create 2 subfolders within `/nfsshare`:
   ```bash 
   curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/nfs-lab/protect.sh | sh
   ```
   `/nfsshare/public` is available to any client while `/nfsshare/private` is available only to superusers. 
2. On both client and server VM, download `create_user.sh`:
   ```bash
   wget https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/nfs-lab/create_user.sh
   ```
3. On both client and server VM, create a new superuser:
   ```bash
   bash create_user.sh alice 3000
   ```
   Superuser IDs should be unique across both server and client.
4. On client VM, create a test user:
    ```bash
    useradd john
    ```
5. On client VM, alice has access to the `/mnt/nfsshare/private` folder but not john. `/mnt/nfsshare/public` is available to both.
