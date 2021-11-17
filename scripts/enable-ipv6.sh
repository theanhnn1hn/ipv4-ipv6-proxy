#!/bin/sh

# centos 7
# bash <(curl -s "https://raw.githubusercontent.com/MohistAttack/ipv4-ipv6-proxy/master/scripts/enable-ipv6.sh?r=$RANDOM")

GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

eecho() {
    echo -e "${GREEN}$1${NC}"
}

eecho "Getting IPv6 ..."
IP6=$(curl -6 -s icanhazip.com -m 10)
if [[ $IP6 != *:* ]]; then
  IP6=
fi

if [ -n "$IP6" ]; then
    eecho "IPv6 = ${IP6}"
    echo -e "${RED}IPv6 Already Enbaled!${NC}"
    exit
fi


while [ ! -n "$ETHNAME" ]; do
  eecho "Please input network interface name: (eth0 as default)"
  read ETHNAME
  if [[ $ETHNAME == "" ]]; then
    ETHNAME="eth0"
  fi
done

while [ ! -n "$ADDR" ]; do
  eecho "Please input ipv6 address: "
  read ADDR
done

while [ ! -n "$GW" ]; do
  eecho "Please input ipv6 gateway address: "
  read GW
done

sed -i '/^NETWORKING_IPV6/d' /etc/sysconfig/network && echo 'NETWORKING_IPV6=yes' >> /etc/sysconfig/network

IFCFGFILE=/etc/sysconfig/network-scripts/ifcfg-$ETHNAME

sed -i '/^IPV6INIT/d' $IFCFGFILE && echo 'IPV6INIT=yes' >> $IFCFGFILE
sed -i '/^IPV6ADDR/d' $IFCFGFILE && echo "IPV6ADDR=$ADDR" >> $IFCFGFILE
sed -i '/^IPV6_DEFAULTGW/d' $IFCFGFILE && echo "IPV6_DEFAULTGW=$GW" >> $IFCFGFILE

systemctl restart network

eecho "IPv6 Enabled."

eecho "Getting IPv6 ..."
IP6=$(curl -6 -s icanhazip.com -m 10)
if [[ $IP6 != *:* ]]; then
  IP6=
fi
eecho "IPv6 = ${IP6}"
