# VPN Lab

## Prerequisites

- 2 VMs: 1 server, 1 client
- Both VMs should be running CentOS 7, connected to the internet, and accessible with root privileges
- CentOS EOL issue must be resolved on both VMs

## Installation

## Server VM

1. Run setup script:  
   ```bash
   curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/vpn-lab/server.sh | bash -s client
   ```
1. Run:
   ```bash
   gedit /etc/openvpn/clients/client.ovpn
   ```
   and copy its contents to your clipboard with `CTRL+A` & `CTRL+C`.

## Client VM

1. Run:
   ```bash
   gedit ~/client.ovpn
   ```
   Paste the copied content from server, then save and exit.

2. Run setup script:
   ```bash
   curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/vpn-lab/client.sh | bash -s ~/client.ovpn
   ```
3. Download the verification script:
   ```bash
   curl -o /usr/local/bin/vpn-verify https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/vpn-lab/vpn-verify
   chmod +x /usr/local/bin/vpn-verify
   ```

## Usage

1. On both client and server VMs, ensure you have root access and internet connectivity.
2. On client VM, connect to the VPN:
   ```bash
   openvpn --config ~/client.ovpn
   ```
3. Open another terminal on client and run:
   ```bash
   vpn-verify
   ```

> [!NOTE]
> The server should start OpenVPN service **automatically** on reboot. If you need to manually restart it, use `systemctl restart openvpn-server@server.service`.

## Verification

| Test Case ID | Description                                                               | Expected Result                                           |
| ------------ | ------------------------------------------------------------------------- | --------------------------------------------------------- |
| TC-01        | Check if the OpenVPN service is running on the server                     | Service status shows **active (running)**                 |
| TC-02        | Client initiates connection to the OpenVPN server                         | Client connects successfully, no errors in logs           |
| TC-03        | Verify VPN tunnel interface (`tun0`) is created on both client and server | `ip addr show tun0` shows interface with assigned VPN IPs |
| TC-04        | On client, trace route to external IP (`traceroute 8.8.8.8`)              | First hop should be VPN server's internal IP (10.8.0.1)   |
| TC-05        | Ping OpenVPN server's VPN IP from client                                  | `ping 10.8.0.1` successful from client                    |
| TC-06        | Ping OpenVPN client's VPN IP from server                                  | `ping 10.8.0.6` successful from server (IP may vary)      |
| TC-07        | Verify encrypted traffic on server WAN interface                          | `tcpdump -i ens33 udp port 1194` shows encrypted packets  |
| TC-08        | Restart OpenVPN service on server                                         | `systemctl restart openvpn-server@server` works           |
| TC-09        | Reboot server, then connect from client                                   | Client reconnects successfully after server reboot        |

## Commands for Manual Testing

```bash
# Check server status
sudo systemctl status openvpn-server@server

# Check VPN interfaces
ip addr show tun0

# Test VPN routing
traceroute 8.8.8.8

# Monitor VPN traffic (on server)
sudo tcpdump -i ens33 udp port 1194

# Check VPN logs
sudo journalctl -u openvpn-server@server -f  # Server logs
sudo journalctl -f | grep openvpn            # Client logs
```

## Uninstallation

To completely remove OpenVPN and EasyRSA:

```bash
curl -s https://raw.githubusercontent.com/creme332/centos-scripts/refs/heads/main/vpn-lab/cleanup.sh |  bash
```