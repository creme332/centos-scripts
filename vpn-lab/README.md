# VPN Lab

## Prerequisites

- 2 VMs: 1 server, 1 client.
- Both VMs should be running CentOS 7, connected to the internet, and accessible with root privileges.

## Installation

1. On server VM:
   1. Run:
      ```bash
      curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/vpn-lab/server.sh | bash -s client
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
      curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/vpn-lab/client.sh | bash -s ~/client.ovpn
      ```

## Usage

1. On both client and server VMs, login as root and connect to the internet.
2. In client VM, connect to server: `vpn connect`.

> [!NOTE]
> The server should start OpenVPN service **automatically** on reboot. If you need to manually restart it, use `systemctl restart openvpn-server@server.service`.

## Verification

| Test Case ID | Description                                                                                    | Expected Result                                          |
| ------------ | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| TC-01        | Check if the OpenVPN service is running on the server (`systemctl status openvpn`)             | Service status shows **active (running)**                |
| TC-02        | Client initiates connection to the OpenVPN server (`vpn connect`)                              | Client connects successfully, no errors in logs          |
| TC-03        | Verify VPN tunnel interface (`tun0`) is created on both client and server                      | `ifconfig` shows `tun0` with assigned VPN IPs            |
| TC-04        | Ping OpenVPN server’s VPN IP from client                                                       | Successful ping response received                        |
| TC-05        | Ping OpenVPN client’s VPN IP from server                                                       | Successful ping response received                        |
| TC-06        | Verify encrypted traffic (check with `tcpdump -i ens33 udp port 1194` on server WAN interface) | Traffic is encapsulated (encrypted), not plain text      |
| TC-07        | Restart OpenVPN service on both client and server                                              | VPN connection re-establishes automatically              |
| TC-08        | Reboot client and reconnect to VPN (`vpn connect`)                                             | Client reconnects successfully to server after reboot    |
| TC-09        | Reboot server and reconnect VPN                                                                | Server comes back online, client reconnects successfully |

## Uninstallation

To complete remove OpenRSA and OpenVPN:

```bash
curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/vpn-lab/clean.sh | sh
```