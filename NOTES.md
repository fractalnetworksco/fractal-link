## Get all existing links on Gateway
```
docker ps --filter "ancestor=etherai/gateway-link:latest"
```

## Export all links to csv
```bash
docker ps \
  --filter 'ancestor=etherai/gateway-link:latest' \
  --format '{{.Names}},{{.Ports}}' | \
while IFS=',' read -r name ports; do
  # Prepare container names and extract port
  original_name=$name
  display_name=$(echo "$name" | tr '-' '.')
  port=$(echo "$ports" | awk -F'[:]' '{print $2}' | awk -F'->' '{print $1}')

  # Fetch WireGuard keys from the container
  keys=$(docker -c selfhosted.pub exec "$original_name" sh -c '
    private_key=$(cat /etc/wireguard/link0.key 2>/dev/null || echo "Private key not found")
    public_key=$LINK_CLIENT_WG_PUBKEY
    echo "$private_key:$public_key"
  ')

  # Split the keys
  IFS=':' read -r private_key public_key <<< "$keys"

  # Output the results
  echo "$display_name, $port, $private_key, $public_key"
done | sed 's/-$//'
```
