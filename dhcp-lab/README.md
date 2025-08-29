# DHCP

## Prerequisites

- 2 VMs: 1 server, 1 client.
- Both VMs should be running CentOS 7, connected to the internet, and accessible with root privileges.

## Installation

On server VM, run:

```bash
curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/server.sh | sh
```

On client VM, run:

```bash
curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/dhcp/dhcp-lab/client.sh | sh
```

## Usage

1. On server VM run: `systemctl start dhcpd && systemctl status dhcpd --no-pager`.

## Verification

| Test Case ID | Description                             | Expected Result                                                                                                                                             |
| ------------ | --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| TC01         | Verify DHCP service is active on server | `systemctl is-active dhcpd` returns `active`                                                                                                                |
| TC02         | Client interface has valid IP           | `ip addr show <iface>` shows IP in `200.100.50.0/24`                                                                                                        |
| TC03         | Connectivity test                       | Client can `ping <server-ip>` successfully                                                                                                                  |
| TC04         | Verify persistence after reboot         | After rebooting both server and client VMs, and following usage instructions, client automatically gets IP in `200.100.50.0/24` without manual intervention |
