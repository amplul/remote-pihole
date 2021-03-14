#!/bin/bash

# PiHole Installation
echo 'PiHole configuration starting...'
# Defining some variables to install PiHole
pihole_interface='eth0'
ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
ip6=$(/sbin/ip -o -6 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
pihole_dns1='1.1.1.1'
pihole_dns2='1.0.0.1'
pihole_dns3='2606:4700:4700::1111'
pihole_dns4='2606:4700:4700::1001'
endpoint='homefox.ovh'

read -r -p 'Enter a password for the PiHole admin interface: ' pihole_password

mkdir /etc/pihole
cat >/etc/pihole/setupVars.conf <<EOF
WEBPASSWORD=$(echo -n "$pihole_password" | sha256sum | awk '{printf "%s",$1 }' | sha256sum)
CONDITIONAL_FORWARDING=false
ADMIN_EMAIL=
WEBUIBOXEDLAYOUT=boxed
WEBTHEME=default-dark
DNSMASQ_LISTENING=all
PIHOLE_INTERFACE=$pihole_interface
IPV4_ADDRESS=$ip4/24
IPV6_ADDRESS=$ip6
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
REV_SERVER=false
PIHOLE_DNS_1=$pihole_dns1
PIHOLE_DNS_2=$pihole_dns2
PIHOLE_DNS_3=$pihole_dns3
PIHOLE_DNS_4=$pihole_dns4
DNSSEC=true
LIGHTTPD_ENABLED=true
CACHE_SIZE=10000
BLOCKING_ENABLED=true
EOF

echo 'Fetching PiHole dependencies...'
apt-get update
apt-get install -y wget
echo 'Installing PiHole...'
wget -O basic-install.sh https://install.pi-hole.net

# Wireguard Installation
echo 'Fetching Wireguard dependencies...'
apt-get install -y wireguard wireguard-dkms wireguard-tools iproute2 qrencode linux-headers-"$(uname -r)" --no-install-recommends
mkdir -p /etc/wireguard/
chmod 700 /etc/wireguard/
Umask 077

## Server creation
echo 'Creating server keys...'
wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
cat >/etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.9.0.1/32
ListenPort = 1194
DNS = $ip4
PrivateKey = $(cat /etc/wireguard/server_private_key)
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

## Peer creation
peer_number_question='How many peers do you need ? [0-9]'
read -r -p "$peer_number_question" peer_number
while [[ ! $peer_number =~ ^[0-9]$ ]]; do
  read -r -p "$peer_number_question" peer_number
done

echo 'Creating peers...'
num=0
while [[ ! $num == "$peer_number" ]]; do
  wg genkey | tee /etc/wireguard/client"$num"_private_key | wg pubkey > /etc/wireguard/client"$num"_public_key
  # Adding peer information to server conf
  cat >/etc/wireguard/wg0.conf <<EOF
[Peer]
#Peer-$num
PublicKey = $(cat /etc/wireguard/client"$num"_public_key)
AllowedIPs = 10.9.0.$(num+2)/32
EOF
  # Generating peer conf file
  cat >/etc/wireguard/peer"$num".conf <<EOF
[Interface]
Address = 10.9.0.$(num+2)/32
DNS = $ip4
PrivateKey = $(cat /etc/wireguard/client"$num"_private_key)

[Peer]
PublicKey = $(cat /etc/wireguard/client"$num"_public_key)
Endpoint = $endpoint:1194
AllowedIPs = 0.0.0.0/0, ::/0
EOF
  ((num=num+1))
done
echo 'Peers successfully created.'

## Setting up launch at startup
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0

## Enable IPv4 forwarding
echo 'Configuring IP Forwarding...'
sed -i 's/\#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sysctl -p
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# Cleanup
echo "Cleaning..."
rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*
echo 'Install done ! Consider rebooting your system.'