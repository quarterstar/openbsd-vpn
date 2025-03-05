#!/bin/ksh

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

wg_pub_key=$1
port=$2
hosts=$3
mtu=$4

# Update the system
pkg_add -u

# Install VPN software (e.g., WireGuard)
pkg_add wireguard-tools

# Configure WireGuard
mkdir -p /etc/wireguard
wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/private.key)
ListenPort = $port
EOF

if [ -n "${mtu}" ]; then
    echo "PostUp = ifconfig wg0 mtu ${mtu}\n" >> /etc/wireguard/wg0.conf
fi

cat >> /etc/wireguard/wg0.conf <<EOF
[Peer]
PublicKey = $wg_pub_key
AllowedIPs = $hosts
EOF

# Enable and start WireGuard
echo "inet 10.1.0.1 255.255.255.0 NONE" > /etc/hostname.wg0
echo "!/usr/local/bin/wg setconf wg0 /etc/wireguard/wg0.conf" >> /etc/hostname.wg0
echo "up" >> /etc/hostname.wg0

# Start the interface
sh /etc/netstart wg0

# Enable packet forwarding
echo 'net.inet.ip.forwarding=1' >> /etc/sysctl.conf
sysctl net.inet.ip.forwarding=1

# Configure firewall (pf)
cat > /etc/pf.conf <<EOF
# Allow inbound traffic on Wireguard interface
pass in on wg0
# Allow all UDP traffic on Wireguard port
pass in inet proto udp from any to any port $port
# Set up a NAT for Wireguard
pass out on egress inet from (wg0:network) nat-to (vio0:0)
EOF

pfctl -f /etc/pf.conf

echo "WireGuard VPN setup finished"
echo "Server's public key: $(cat /etc/wireguard/public.key)"
