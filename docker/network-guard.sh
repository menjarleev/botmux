#!/bin/sh
# Refs #3: rules affect only this container's private network namespace.
set -eu

iptables -w -P OUTPUT DROP
iptables -w -F OUTPUT
iptables -w -A OUTPUT -o lo -j ACCEPT
iptables -w -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
for subnet in \
  0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 \
  169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 \
  192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 \
  224.0.0.0/4 240.0.0.0/4; do
  iptables -w -A OUTPUT -d "$subnet" -j REJECT
done
iptables -w -A OUTPUT -j ACCEPT

# IPv6 has no public egress in this profile; do not leave an alternate route.
ip6tables -w -P OUTPUT DROP
ip6tables -w -F OUTPUT
ip6tables -w -A OUTPUT -o lo -j ACCEPT
ip6tables -w -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

touch /run/network-ready
trap 'exit 0' INT TERM
while :; do
  sleep 3600 &
  wait "$!"
done
