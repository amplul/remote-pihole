#!/bin/bash

# PiHole Installation
echo 'PiHole configuration starting...'
# Defining some variables to install PiHole
pihole_interface='eth0'
ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1 | head -n 1)
ip6=$(/sbin/ip -o -6 addr list eth0 | awk '{print $4}' | cut -d/ -f1 | head -n 1)
pihole_dns1='1.1.1.1'
pihole_dns2='1.0.0.1'
pihole_dns3=''
pihole_dns4=''

read -r -p 'Enter a password for the PiHole admin interface: ' pihole_password

mkdir /etc/pihole
cat >/etc/pihole/setupVars.conf <<EOF
WEBPASSWORD=$(echo -n "$pihole_password" | sha256sum | awk '{printf "%s",$1 }' | sha256sum | head -n1 | cut -d " " -f1)
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
chmod +x basic-install.sh
./basic-install.sh --unattended

# Wireguard Installation
echo 'Installing a VPN with PiVPN...'
curl -L https://install.pivpn.io | bash

# Cleanup
echo 'Cleaning...'
rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*
echo 'Install done ! Consider rebooting your system.'
echo 'You can add peers to your vpn with "pivpn add"'
echo 'You can display your peer profile with "pivpn -qr"'