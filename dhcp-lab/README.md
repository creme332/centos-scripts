# DHCP

## Prerequisites

- 2 VMs: 1 server, 1 client.
- Both VMs should be running CentOS 7, connected to the internet, and accessible with root privileges.

## Installation

On server VM, download the setup script:

```bash
curl -o ~/server.sh https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/server.sh
```

Then, to setup DHCP, run:

```bash
bash ~/server.sh [SERVER_IP] [RANGE_START] [RANGE_END] [SUBNET] [NETMASK]

# Example
bash ~/server.sh 200.100.50.10 200.100.50.1.100 200.100.50.25 200.100.50.0 255.255.255.0
```

where `[SERVER_IP]`, `[RANGE_START]`, `[RANGE_END]`, `[SUBNET]`, and `[NETMASK]` are **placeholders that you must substitute with IP addresses**.

| Parameter     | Description                                                                 | Default Value |
| ------------- | --------------------------------------------------------------------------- | ------------- |
| `SERVER_IP`   | Static IP address for the DHCP server. Choose any IP within the DHCP range. | 200.100.50.10 |
| `RANGE_START` | First IP address in the DHCP pool.                                          | 200.100.50.1  |
| `RANGE_END`   | Last IP address in the DHCP pool.                                           | 200.100.50.25 |
| `SUBNET`      | Network subnet address. It is the bitwise AND of `SERVER_IP` and `NETMASK`. | 200.100.50.0  |
| `NETMASK`     | Subnet mask for the network.                                                | 255.255.255.0 |

On client VM, run:

```bash
curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/client.sh | sh
```

## Usage

1. On server VM, to start DHCP server and check status: `systemctl start dhcpd && systemctl status dhcpd`.
2. On client VM, to request IP from DHCP server: `systemctl restart network && ip addr show`.

## Verification

| Test Case ID | Description                             | Expected Result                                                                                                                                   |
| ------------ | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| TC01         | Verify DHCP service is active on server | `systemctl is-active dhcpd` returns `active`                                                                                                      |
| TC02         | Client interface has valid IP           | `ip addr show <iface>` shows IP in `200.100.50.0/24`                                                                                              |
| TC03         | Connectivity test                       | Client can `ping <server-ip>` successfully                                                                                                        |
| TC04         | Verify persistence after reboot         | After rebooting both server and client VMs, and following usage instructions, client automatically gets configured IP without manual intervention |

## Uninstallation

```sh
# Server
curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/uninstall-server.sh | sh

# Client
curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/uninstall-client.sh | sh
```