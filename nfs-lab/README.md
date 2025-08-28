
# NFS Lab

## Basic Setup

1. Open 2 VMs, one for client and another one for server.
2. In both VMs:
   1. Login as root with `su -`.
   2. Connect to the internet.
   3. Note down the machine IP address using `ifconfig ens33 | awk '/inet / {print $2}'`.
3. On server VM, run the following command and replace `192.168.136.50` with the **client's** IP:
    ```bash
    curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/nfs-lab/nfs-server.sh | bash -s -- 192.168.136.50
    ```
4. On client VM, run `nfs-client.sh` and replace `192.168.136.100` with the **server's** IP:
    ```bash
    curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/nfs-lab/nfs-client.sh | bash -s -- 192.168.136.100
    ```

> [!NOTE]
> Each time you restart the client VM, you need to reconnect to the internet and run `mount -a` as root.


### Verification

| Test Case ID | Description                                                            | Expected Result                                      |
| ------------ | ---------------------------------------------------------------------- | ---------------------------------------------------- |
| TC-01        | On client, mount NFS export from server to `/mnt/nfsshare`             | Mount succeeds; `df -h` shows `/mnt/nfsshare`        |
| TC-02        | On client, create a file in `/mnt/nfsshare`                            | File is created and visible in `/nfsshare` on server |
| TC-03        | On server, create a file in `/nfsshare`                                | File is visible in `/mnt/nfsshare` on client         |
| TC-04        | On client, delete a file in `/mnt/nfsshare`                            | File is removed from `/nfsshare` on server           |
| TC-05        | On server, delete a file in `/nfsshare`                                | File is removed from `/mnt/nfsshare` on client       |
| TC-06        | Verify permissions (read/write/execute) from client on `/mnt/nfsshare` | Access matches export configuration                  |
| TC-07        | Restart NFS server service                                             | Client retains/re-establishes access without errors  |


## Extra: Authentication

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
