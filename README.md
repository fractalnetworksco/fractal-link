# fractal-link
A Docker native Reverse-Proxy-over-VPN Framework

```
pip install fractal-link
```

2. Create a link
```
# http(s) + SNI
fractal link init https://link.mydomain.com via user@gateway.com

# raw tcp
fractal link init tcp://25:postfix:25 via user@gateway.com

# raw udp
fractal link init udp://51820:wireguard:51820 via user@gateway.com
```

3. Up the link (on Gateway)
```
# Docker compose output
fractal link up link.mydomain.com --compose

# Wireguard output
fractal link up link.mydomain.com --wireguard

# TCP Wireguard example
fractal link up tcp://25:postfix:25 --wireguard
```
Note: You still need to activate a local WireGuard interface or up your docker compose project.

4. Edit the link
```
fractal link edit link.mydomain.com
<editor opens gateway link compose file, changes applied on save>
```

5. Down the link (on Gateway)
```
fractal link down link.mydomain.com
```

6. Destroy the link
```
# http(s)
fractal link rm link.mydomain.com

# tcp
fractal link rm tcp://25:postfix:25
```
