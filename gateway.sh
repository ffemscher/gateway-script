#!/bin/bash
#########################################################
#  _______            __  ___             __            #
# |   _   .----.-----|__.'  _.--.--.-----|  |--.        #
# |.  1___|   _|  -__|  |   _|  |  |     |    <         #
# |.  __) |__| |_____|__|__| |_____|__|__|__|__|        #
# |:  |                                                 #
# |::.|         Multi-Community Gateway                 #
# `---'                                                 #
#                                                       #
# Mesh: batman-adv,alfred,batadv-vis                    #
# Mesh-VPN: fastd - Backbone: L2TP                      #
#                                            03.09.2015 #
#########################################################
#
## node01.xxx.xxx.de


### Routing
ip rule add from all fwmark 0x1 table 42
ip rule add from 10.0.0.0/8 pref 10 table 42
ip rule add to 10.0.0.0/8 pref 10 table 42
ip -6 rule add from 2a03:2260:50::/44 pref 10 table 42
ip -6 rule add to 2a03:2260:50::/44 pref 10 table 42

sysctl -w net.ipv6.conf.all.forwarding=1
sysctl -w net.ipv4.ip_forward=1

# Block Fastd over Fastd
iptables -A INPUT -s 185.66.192.0/22 -i eth0 -p udp -m udp --dport 10000 -m limit --limit 2/sec -j LOG --log-prefix 'fastd over mesh: '
iptables -A INPUT -s 185.66.192.0/22 -i eth0 -p udp -m udp --dport 10000 -j REJECT --reject-with icmp-admin-prohibited
ip6tables -A INPUT -s 2a03:2260::/30 -i eth0 -p udp -m udp --dport 10000 -m limit --limit 2/sec -j LOG --log-prefix 'fastd over mesh: '
ip6tables -A INPUT -s 2a03:2260::/30 -i eth0 -p udp -m udp --dport 10000 -j REJECT --reject-with icmp6-adm-prohibited

# Kernel-Module
modeprobe batman-adv
modprobe l2tp_core
modprobe l2tp_eth
modprobe l2tp_netlink
modprobe l2tp_debugfs
modprobe l2tp_ip


#########################################################
### Entenhausen (ffente)                                #
#########################################################

## Mesh-Bridge
brctl addbr br-ente
ip a add 10.xx.xx.1/17 dev br-ente
ip -6 a add 2a03:2260:xx:xx::16/64 dev br-ente
ip rule add iif br-ente pref 10 table 42
ip link set dev br-ente up
iptables -t mangle -A PREROUTING -i br-ente -j MARK --set-xmark 0x1/0xffffffff
start-stop-daemon -b -n dnsmasq-ente --start --exec /usr/sbin/dnsmasq -- -C /home/node01/conf/dnsmasq-ente.conf

## Batman
ip link add dev bat-ente type batadv
ip link set address 02:1b:0b:c0:de:1b dev bat-ente
batctl -m bat-ente it 5000
batctl -m bat-ente bl 1
batctl -m bat-ente gw server 48mbit/48mbit
brctl addif br-ente bat-ente
ip link set dev bat-ente up
iptables -t mangle -A PREROUTING -i bat-ente -j MARK --set-xmark 0x1/0xffffffff
ebtables -A FORWARD -p IPv6 -i bat-ente --ip6-proto ipv6-icmp --ip6-icmp-type router-advertisement -j DROP
echo 120 > /sys/class/net/bat-ente/mesh/hop_penalty

## Alfred
ip link add name alfred-ente link br-en type macvlan
ip link set dev alfred-ente mtu 1280
ip link set up dev alfred-ente
iptables -t mangle -A PREROUTING -i alfred-ente -j MARK --set-xmark 0x1/0xffffffff
start-stop-daemon -b --start -n alfred-ente --exec /usr/local/sbin/alfred -- -i alfred-ente -u /tmp/alfred-ente.sock -b bat-ente
start-stop-daemon -b --start -n batadv-ente --exec /usr/local/sbin/batadv-vis -- -i bat-ente -s -u /tmp/alfred-ente.sock

## Fastd
fastd -d --status-socket /tmp/fastd-ente.socket --config conf/fastd-ente.conf


#########################################################
### Gotham (ffgo)                                       #
#########################################################

## Mesh-Bridge
brctl addbr br-go
ip a add 10.xx.xxx.1/18 dev br-go
ip -6 a add 2a03:2260:xx:xx::128/64 dev br-go
ip rule add iif br-go pref 10 table 42
ip link set dev br-go up
iptables -t mangle -A PREROUTING -i br-go -j MARK --set-xmark 0x1/0xffffffff
start-stop-daemon -b -n dnsmasq-go --start --exec /usr/sbin/dnsmasq -- -C /home/node01/conf/dnsmasq-go.conf

## Batman
ip link add dev bat-go type batadv
ip link set address 02:2b:0b:c0:de:1b dev bat-go
batctl -m bat-go it 5000
batctl -m bat-go bl 1
batctl -m bat-go gw server 48mbit/48mbit
brctl addif br-go bat-go
ip link set dev bat-go up
iptables -t mangle -A PREROUTING -i bat-go -j MARK --set-xmark 0x1/0xffffffff
ebtables -A FORWARD -p IPv6 -i bat-go --ip6-proto ipv6-icmp --ip6-icmp-type router-advertisement -j DROP
echo 120 > /sys/class/net/bat-go/mesh/hop_penalty

## Alfred
ip link add name alfred-go link br-go type macvlan
ip link set dev alfred-go mtu 1280
ip link set up dev alfred-go
iptables -t mangle -A PREROUTING -i alfred-go -j MARK --set-xmark 0x1/0xffffffff
start-stop-daemon -b --start -n alfred-go --exec /usr/local/sbin/alfred -- -i alfred-go -u /tmp/alfred-go.sock -b bat-go
start-stop-daemon -b --start -n batadv-go --exec /usr/local/sbin/batadv-vis -- -i bat-go -s -u /tmp/alfred-go.sock

## Fastd
fastd -d --status-socket /tmp/fastd-go.socket --config conf/fastd-go.conf


#########################################################
### Paragon City (ffpa)                                 #
#########################################################

## Mesh-Bridge
brctl addbr br-pa
ip a add 10.xx.xxx.1/18 dev br-pa
ip -6 a add 2a03:2260:xx:xx::192/64 dev br-pa
ip rule add iif br-pa pref 10 table 42
ip link set dev br-pa up
iptables -t mangle -A PREROUTING -i br-pa -j MARK --set-xmark 0x1/0xffffffff
start-stop-daemon -b -n dnsmasq-pa --start --exec /usr/sbin/dnsmasq -- -C /home/node01/conf/dnsmasq-pa.conf

## Batman
ip link add dev bat-pa type batadv
ip link set address 02:3b:0b:c0:de:1b dev bat-pa
batctl -m bat-pa it 5000
batctl -m bat-pa bl 1
batctl -m bat-pa gw server 48mbit/48mbit
brctl addif br-pa bat-pa
ip link set dev bat-pa up
iptables -t mangle -A PREROUTING -i bat-pa -j MARK --set-xmark 0x1/0xffffffff
ebtables -A FORWARD -p IPv6 -i bat-pa --ip6-proto ipv6-icmp --ip6-icmp-type router-advertisement -j DROP
echo 120 > /sys/class/net/bat-pa/mesh/hop_penalty

## Alfred
ip link add name alfred-pa link br-pa type macvlan
ip link set dev alfred-pa mtu 1280
ip link set up dev alfred-pa
iptables -t mangle -A PREROUTING -i alfred-pa -j MARK --set-xmark 0x1/0xffffffff
start-stop-daemon -b --start -n alfred-pa --exec /usr/local/sbin/alfred -- -i alfred-pa -u /tmp/alfred-pa.sock -b bat-pa
start-stop-daemon -b --start -n batadv-pa --exec /usr/local/sbin/batadv-vis -- -i bat-pa -s -u /tmp/alfred-pa.sock

## Fastd
fastd -d --status-socket /tmp/fastd-pa.socket --config conf/fastd-pa.conf


##########################################################
## Backbone Konfiguration (L2TPv3)                      ##
##                                                      ##
##                                                      ##
## tunnel_id = {local.node}{1}{remote.node}             ##
## peer_tunnel_id = {remote.node}{1}{local.node}        ##
##                                                      ##
## udp_sport = {1}{local.node}{00}{remote.node}         ##
## udp_dport = {1}{remote.node}{00}{local.node}         ##
##                                                      ##
## session_id = {local.node}{domain}{remote.node}       ##
## peer_session_id = {remote.node}{domain}{local.node}  ##
##########################################################
#
# Domain { ente = 1 , go = 2 , pa = 3 }
#

## L2P-Tunnel zu den Supernodes / Map-Server

ip l2tp add tunnel tunnel_id 112 peer_tunnel_id 211 udp_sport 11002 udp_dport 12001 encap udp local 100.90.80.70 remote 88.99.77.55
ip l2tp add tunnel tunnel_id 113 peer_tunnel_id 311 udp_sport 11003 udp_dport 13001 encap udp local 100.90.80.70 remote 88.77.66.56
ip l2tp add tunnel tunnel_id 114 peer_tunnel_id 411 udp_sport 11004 udp_dport 14001 encap udp local 100.90.80.70 remote 88.77.66.57
ip l2tp add tunnel tunnel_id 115 peer_tunnel_id 511 udp_sport 11005 udp_dport 15001 encap udp local 100.90.80.70 remote 88.77.66.58
ip l2tp add tunnel tunnel_id 116 peer_tunnel_id 611 udp_sport 11006 udp_dport 16001 encap udp local 100.90.80.70 remote 88.77.66.59
ip l2tp add tunnel tunnel_id 117 peer_tunnel_id 711 udp_sport 11007 udp_dport 17001 encap udp local 100.90.80.70 remote 88.77.66.60

### L2P-Sessions der Domains

## BBENTE
ip l2tp add session name bbente-node02 tunnel_id 112 session_id 112 peer_session_id 211
ip link set bbente-node02 address 02:1b:bb:c0:d1:2b
ip link set bbente-node02 up mtu 1488
batctl -m bat-ente if add bbente-node02

ip l2tp add session name bbente-node03 tunnel_id 113 session_id 113 peer_session_id 311
ip link set bbente-node03 address 02:1b:bb:c0:d1:3b
ip link set bbente-node03 up mtu 1488
batctl -m bat-ente if add bbente-node03

ip l2tp add session name bbente-node04 tunnel_id 114 session_id 114 peer_session_id 411
ip link set bbente-node04 address 02:1b:bb:c0:d1:4b
ip link set bbente-node04 up mtu 1488
batctl -m bat-ente if add bbente-node04

ip l2tp add session name bbente-node05 tunnel_id 115 session_id 115 peer_session_id 511
ip link set bbente-node05 address 02:1b:bb:c0:d1:5b
ip link set bbente-node05 up mtu 1488
batctl -m bat-ente if add bbente-node05

ip l2tp add session name bbente-node06 tunnel_id 116 session_id 116 peer_session_id 611
ip link set bbente-node06 address 02:1b:bb:c0:d1:6b
ip link set bbente-node06 up mtu 1488
batctl -m bat-ente if add bbente-node06

ip l2tp add session name bbente-map tunnel_id 117 session_id 117 peer_session_id 711
ip link set bbente-map address 02:1b:bb:c0:d1:7b
ip link set bbente-map up mtu 1488
batctl -m bat-ente if add bbente-map

## BBGO
ip l2tp add session name bbgo-node02 tunnel_id 112 session_id 122 peer_session_id 221
ip link set bbgo-node02 address 02:2b:bb:c0:d1:2b
ip link set bbgo-node02 up mtu 1488
batctl -m bat-go if add bbgo-node02

ip l2tp add session name bbgo-node03 tunnel_id 113 session_id 123 peer_session_id 321
ip link set bbgo-node03 address 02:2b:bb:c0:d1:3b
ip link set bbgo-node03 up mtu 1488
batctl -m bat-go if add bbgo-node03

ip l2tp add session name bbgo-node04 tunnel_id 114 session_id 124 peer_session_id 421
ip link set bbgo-node04 address 02:2b:bb:c0:d1:4b
ip link set bbgo-node04 up mtu 1488
batctl -m bat-go if add bbgo-node04

ip l2tp add session name bbgo-node05 tunnel_id 115 session_id 125 peer_session_id 521
ip link set bbgo-node05 address 02:2b:bb:c0:d1:5b
ip link set bbgo-node05 up mtu 1488
batctl -m bat-go if add bbgo-node05

ip l2tp add session name bbgo-node06 tunnel_id 116 session_id 126 peer_session_id 621
ip link set bbgo-node06 address 02:2b:bb:c0:d1:6b
ip link set bbgo-node06 up mtu 1488
batctl -m bat-go if add bbgo-node06

ip l2tp add session name bbgo-map tunnel_id 117 session_id 127 peer_session_id 721
ip link set bbgo-map address 02:2b:bb:c0:d1:7b
ip link set bbgo-map up mtu 1488
batctl -m bat-go if add bbgo-map

## BBPA
ip l2tp add session name bbpa-node02 tunnel_id 112 session_id 132 peer_session_id 231
ip link set bbpa-node02 address 02:3b:bb:c0:d1:2b
ip link set bbpa-node02 up mtu 1488
batctl -m bat-pa if add bbpa-node02

ip l2tp add session name bbpa-node03 tunnel_id 113 session_id 133 peer_session_id 331
ip link set bbpa-node03 address 02:3b:bb:c0:d1:3b
ip link set bbpa-node03 up mtu 1488
batctl -m bat-pa if add bbpa-node03

ip l2tp add session name bbpa-node04 tunnel_id 114 session_id 134 peer_session_id 431
ip link set bbpa-node04 address 02:3b:bb:c0:d1:4b
ip link set bbpa-node04 up mtu 1488
batctl -m bat-pa if add bbpa-node04

ip l2tp add session name bbpa-node05 tunnel_id 115 session_id 135 peer_session_id 531
ip link set bbpa-node05 address 02:3b:bb:c0:d1:5b
ip link set bbpa-node05 up mtu 1488
batctl -m bat-pa if add bbpa-node05

ip l2tp add session name bbpa-node06 tunnel_id 116 session_id 136 peer_session_id 631
ip link set bbpa-node06 address 02:3b:bb:c0:d1:6b
ip link set bbpa-node06 up mtu 1488
batctl -m bat-pa if add bbpa-node06

ip l2tp add session name bbpa-map tunnel_id 117 session_id 137 peer_session_id 731
ip link set bbpa-map address 02:3b:bb:c0:d1:7b
ip link set bbpa-map up mtu 1488
batctl -m bat-pa if add bbpa-map
