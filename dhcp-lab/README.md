# DHCP

## Prerequisites

- 2 VMs: 1 server, 1 client.
- Both VMs should be running CentOS 7, connected to the internet, and accessible with root privileges.

## Installation

On server VM, download the installation and uninstallation scripts:

```bash
curl -o ~/server.sh https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/server.sh
curl -o ~/uninstall-server.sh https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/uninstall-server.sh
```

Then, run the installation script as follows:

```bash
bash ~/server.sh [SERVER_IP] [RANGE_START] [RANGE_END] [NETMASK] [GATEWAY]

# Example
bash ~/server.sh 200.100.50.99 200.100.50.1.100 200.100.50.25 200.100.50.0 255.255.255.0
```

where `[SERVER_IP]`, `[RANGE_START]`, `[RANGE_END]`, `[SUBNET]`, and `[NETMASK]` are **placeholders that you must substitute with IP addresses**.

| Parameter     | Description                                            | Example       |
| ------------- | ------------------------------------------------------ | ------------- |
| `SERVER_IP`   | Static IP for DHCP server (must be outside DHCP range) | 192.168.1.99  |
| `RANGE_START` | First IP address in the DHCP pool                      | 192.168.1.100 |
| `RANGE_END`   | Last IP address in the DHCP pool                       | 192.168.1.150 |
| `NETMASK`     | Subnet mask for the network                            | 255.255.255.0 |
| `GATEWAY`     | Default gateway IP                                     | 192.168.1.1   |

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

1. On server VM:
   1. Start DHCP server: `systemctl status dhcpd`.
   2. Ensure that server was properly started: `systemctl status dhcpd`.
2. On client VM:
   1. Request IP from DHCP server: `systemctl restart network`.
   2. Check that the IP is within the DHCP range: `ifconfig ens33`.

## Verification

| Test Case ID | Description                             | Expected Result                                                                                                                                   |
| ------------ | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| TC01         | Verify DHCP service is active on server | `systemctl is-active dhcpd` returns `active`                                                                                                      |
| TC02         | Client interface has valid IP           | `ifconfig ens33` shows IP in DHCP range                                                                                                           |
| TC03         | Connectivity test                       | Client can `ping <server-ip>` successfully                                                                                                        |
| TC04         | Verify persistence after reboot         | After rebooting both server and client VMs, and following usage instructions, client automatically gets configured IP without manual intervention |

## Troubleshooting

**Server Issues:**
- Check logs: `journalctl -u dhcpd -n 20`
- Verify interface: `ip addr show`
- Check config: `dhcpd -t -cf /etc/dhcp/dhcpd.conf`

**Client Issues:**
- Force DHCP renewal: `dhclient -r && dhclient`
- Check network config: `cat /etc/sysconfig/network-scripts/ifcfg-ens33`
- Check DHCP lease file: `/var/lib/dhclient/dhclient-<interface>.lease`
- View DHCP logs: `journalctl -u network -n 20`

## Uninstallation

```sh
# Server
bash ~/uninstall-server.sh --force

# Client
bash ~/uninstall-client.sh --force
```