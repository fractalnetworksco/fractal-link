# etherai-link
A Docker native Reverse-Proxy-over-VPN Framework

```
pip install etherai-link
```

2. Create a link
```
# http(s) + SNI
etherai link init https://link.mydomain.com to nginx:80 via user@gateway.com

# raw tcp
etherai link init tcp://25:postfix:25,tcp://587:postfix:587 via user@gateway.com
# OR
etherai link init TCP4-LISTEN:25,TCP4:postfix:25 TCP4-LISTEN:587,TCP4:postfix:587 via user@gateway.com

# raw udp
etherai link init udp://51820:wireguard:51820 via user@gateway.com
```

3. Up the link (on Gateway)
```
# Docker compose output
etherai link up link.mydomain.com # defaults to outputting docker compose link service yaml
<docker compose link snippet>

# Optional WireGuard config output
etherai link up link.mydomain.com --wireguard

# TCP Wireguard example
etherai link up tcp://25:postfix:25 --wireguard
```
Note: You still need to activate a local WireGuard interface with the provided config OR `docker compose -f link.mydomain.com.link.yaml -f docker-copose.yaml up -d` your docker compose project.

4. Edit a link
```
etherai link edit link.mydomain.com
<editor opens gateway link compose file, changes applied on save>
```

5. Down a link (on Gateway)
```
etherai link down link.mydomain.com
```

6. Destroy a link
```
# http(s)
etherai link rm link.mydomain.com

# tcp
etherai link rm tcp://25:postfix:25
```
