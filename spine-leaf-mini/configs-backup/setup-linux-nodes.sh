#!/bin/bash
docker exec clab-spine-leaf-mini-web01 bash -c "
apt update -qq && apt install -y -qq iproute2 iputils-ping curl apache2
ip addr add 172.16.1.10/24 dev eth1
ip link set eth1 mtu 1500
ip link set eth1 up
ip route add 172.16.0.0/16 via 172.16.1.1
service apache2 start
"
docker exec clab-spine-leaf-mini-db01 bash -c "
apt update -qq && apt install -y -qq iproute2 iputils-ping curl mysql-server
ip addr add 172.16.2.10/24 dev eth1
ip link set eth1 mtu 1500
ip link set eth1 up
ip route add 172.16.0.0/16 via 172.16.2.1
service mysql start
"
docker exec clab-spine-leaf-mini-edge bash -c "
ip addr add 192.0.2.2/30 dev eth1
ip link set eth1 mtu 1500
ip link set eth1 up
ip route add 172.16.0.0/16 via 192.0.2.1
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
"
echo "Da cau hinh xong web01, db01, edge (MTU 1500)."
