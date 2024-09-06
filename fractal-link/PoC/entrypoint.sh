#!/bin/sh

KEY_PATH="/etc/wireguard/link0.key"

echo $GATEWAY_LINK_WG_PRIVKEY > "$KEY_PATH"


ip link add link0 type wireguard

wg set link0 private-key /etc/wireguard/link0.key
wg set link0 listen-port 18521
ip addr add 10.0.0.1/24 dev link0
ip link set link0 up
ip link set link0 mtu $LINK_MTU

wg set link0 peer $CLIENT_LINK_WG_PUBKEY allowed-ips 10.0.0.2/32

"$@"

exec tail -f /dev/null
