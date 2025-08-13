
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

To setup an NFS client & server on the **same** machine :

```bash
curl https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/nfs-lab/nfs.sh | sh
```