# VPN Lab

>[!CAUTION]
The following instructions have **not** been tested at all.

## Prerequisites

- 2 VMs: 1 server, 1 client.
- Both VMs should be running CentOS 7 (or compatible), connected to the internet, and accessible with root privileges.
- `wget` and `gedit` must be installed.

## Basic Setup

1. On server VM:
   1. Run:
      ```bash
      wget -qO- https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/vpn/vpn-lab/server.sh | bash -s client
      ```
   2. Copy the contents of `/etc/openvpn/clients/client.ovpn` to your clipboard.

2. On client VM:
   1. Run:
      ```bash
      gedit ~/client.ovpn
      ```
      and paste the recently copied text. Save the file.
   2. Run:
      ```bash
      wget -qO- https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/vpn/vpn-lab/client.sh | bash -s ~/client.ovpn
      ```