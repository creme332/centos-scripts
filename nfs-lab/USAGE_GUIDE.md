
# NFS

## Different machines

1. Open 2 VMs, one for client and another one for server.
2. In both VMs:
   1. Login as root.
   2. Connect to the internet.
   3. Note down the IPs using `ifconfig`.
3. On server VM, run `nfs-server.sh` and enter the client IP when prompted:
    ```bash
    curl https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/nfs-lab/nfs-server.sh | sh
    ```
4. On client VM, run `nfs-client.sh` and enter the server IP when prompted:
    ```bash
    curl https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/nfs-lab/nfs-client.sh | sh
    ```
## Same machine

To setup an NFS client & server on the **same** machine :

```bash
curl https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/nfs-lab/nfs.sh | sh
```