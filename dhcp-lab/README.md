# DHCP

## Prerequisites

- 2 VMs: 1 server, 1 client.
- Both VMs should be running CentOS 7, connected to the internet, and accessible with root privileges.
- **Both VMs should in NAT networking mode**.

> [!IMPORTANT]
> Both VMs should be in the NAT networking mode.

## Installation

On server VM, download the installation and uninstallation scripts:

```bash
curl -o ~/server.sh https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/server.sh
curl -o ~/uninstall-server.sh https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/uninstall-server.sh
```

Then, run the installation script as follows:

```bash
bash ~/server.sh [RANGE_START] [RANGE_END] [NETMASK] [GATEWAY]

# Examples
# a)
bash ~/server.sh 175.200.225.1 175.200.225.25 255.255.192.0 175.200.225.1

# b)
bash ~/server.sh 125.150.175.100 125.150.175.125 255.248.0.0 125.150.175.100

# c)
bash ~/server.sh 200.205.210.50 200.205.210.75 255.255.255.128 200.205.210.50
```

---

On client VM, download the installation and uninstallation scripts:

```bash
curl -o ~/client.sh https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/client.sh
curl -o ~/uninstall-client.sh https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/uninstall-client.sh
```

then run the installation script:

```bash
bash ~/client.sh
```

## Usage

1. Open Powershell on Windows with **administrative rights** and run `net stop vmnetdhcp`.
2. On server VM:
   1. Start DHCP server: `systemctl start dhcpd`.
   2. Ensure that server was properly started: `systemctl status dhcpd`.
3. On client VM:
   1. Request IP from DHCP server: `dhclient -r ens33 && dhclient -v ens33`.
   2. Check that the IP is within the DHCP range: `ifconfig ens33`.

## Uninstallation

```sh
# Server
bash ~/uninstall-server.sh

# Client
bash ~/uninstall-client.sh
```