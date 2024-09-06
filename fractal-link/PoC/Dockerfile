FROM alpine:latest

ADD entrypoint.sh jpf.sh /usr/bin/

RUN apk add nftables wireguard-tools

ENV LINK_MTU=1380

ENTRYPOINT [ "entrypoint.sh" ]
