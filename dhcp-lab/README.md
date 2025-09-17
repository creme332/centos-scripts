# DHCP

## Prerequisites

- 2 VMs: 1 server, 1 client.
- Both VMs should be running CentOS 7, connected to the internet, and accessible with root privileges.

## Installation

On server VM, run:

```bash
curl -o ~/server.sh https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/server.sh
bash ~/server.sh --help
```

To use a different IP range, run the server script with parameters:
```bash
# Example: Use 192.168.1.x network
bash ~/server.sh 192.168.1.10 192.168.1.100 192.168.1.150 192.168.1.0
```

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