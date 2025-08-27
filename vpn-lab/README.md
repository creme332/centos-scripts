# VPN Lab

>[!CAUTION]
The following instructions have **not** been tested at all.

## Prerequisites

- 2 VMs: 1 for server and 1 for client
- Both VMs should be connected to the internet and be login as root access.
- 

## Basic Setup

1. On server VM:
   1.  Run:
       ```bash
       wget https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/vpn/vpn-lab/server.sh
       bash server.sh client
       ```
   2. Copy the contents of `/etc/openvpn/clients/client.ovpn` to your clipboard.
2. On client VM:
   1. Run `gedit ~/client.ovpn` and paste the recently copied text. Save the file.
   2. Run:
      ```bash
      wget https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/vpn/vpn-lab/client.sh
      bash client.sh ~/client.ovpn
      ```