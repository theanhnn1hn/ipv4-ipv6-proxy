#!/bin/sh

# bash <(curl -s "https://raw.githubusercontent.com/MohistAttack/ipv4-ipv6-proxy/master/scripts/ipv4-ipv6.sh")

GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

eecho() {
    echo -e "${GREEN}$1${NC}"
}

while [ ! $PROXYCOUNT ] || [[ $PROXYCOUNT -lt 1 ]] || [[ $PROXYCOUNT -gt 10000 ]]; do
    eecho "How many proxy do you want to create? 1-10000"
    read PROXYCOUNT
done

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com)
if [[ $IP6 != *:* ]]; then
  IP6=
fi

eecho "IPv4 = ${IP4}. IPv6 = ${IP6}"

if [ ! -n "$IP4" ]; then
  eecho "IPv4 Nout Found. Exit"
  exit
fi

while [[ $IP6 != *:* ]] || [ ! -n "$IP6" ]; do
  eecho "Invalid IPv6, Please input it manually:"
  read IP6
done

while [[ $IP6PREFIXLEN -ne 64 ]] && [[ $IP6PREFIXLEN -ne 112 ]]; do
    eecho "Please input prefixlen for IPv6: (64/112, 112 as default)"
    read IP6PREFIXLEN
    if [ ! $IP6PREFIXLEN ]; then
        IP6PREFIXLEN=112
    fi
done

if [ $IP6PREFIXLEN -eq 64 ]; then
    IP6PREFIX=$(echo $IP6 | cut -f1-4 -d':')
fi
if [ $IP6PREFIXLEN -eq 112 ]; then
    IP6PREFIX=$(echo $IP6 | rev | cut -f2- -d':' | rev)
fi
eecho "IPv6 PrefixLen: $IP6PREFIXLEN --> Prefix: $IP6PREFIX"

while [ ! -n "$ETHNAME" ]; do
  eecho "Please input network interface name: (eth0 as default)"
  read ETHNAME
  if [[ $ETHNAME == "" ]]; then
    ETHNAME="eth0"
  fi
done

while [ ! -n "$PROXYUSER" ]; do
    eecho "Please input username for proxy: (smile as default)"
    read PROXYUSER
    if [[ $PROXYUSER == "" ]]; then
        PROXYUSER="smile"
    fi
done

while [ ! -n "$PROXYPASS" ]; do
    eecho "Please input password for proxy: (girl as default)"
    read PROXYPASS
    if [[ $PROXYPASS == "" ]]; then
        PROXYPASS="girl"
    fi
done

#################### functions ####################
install_3proxy() {
    eecho "Installing 3proxy ..."
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cp ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
    chmod +x /etc/init.d/3proxy
    chkconfig 3proxy on
    cd $WORKDIR
}

gen_data() {
    array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
    ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}

    seq 1 $PROXYCOUNT | while read idx; do
        port=$(($idx+10000))
        if [[ $IP6PREFIXLEN -eq 112 ]]; then
            suffix=$(($idx+1))
            suffix=$(printf '%x\n' $suffix)
            echo "$PROXYUSER/$PROXYPASS/$IP4/$port/$IP6PREFIX:$suffix"
        fi
        if [[ $IP6PREFIXLEN -eq 64 ]]; then
            echo "$PROXYUSER/$PROXYPASS/$IP4/$port/$IP6PREFIX:$(ip64):$(ip64):$(ip64):$(ip64)"
        fi
    done
}

gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -v ETHNAME="$ETHNAME" -v IP6PREFIXLEN="$IP6PREFIXLEN" -F "/" '{print "ifconfig " ETHNAME " inet6 add " $5 "/" IP6PREFIXLEN}' ${WORKDATA})
EOF
}

gen_proxy_file() {
    cat <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

# https://3proxy.ru/doc/man3/3proxy.cfg.3.html
gen_3proxy() {
# users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})
    cat <<EOF
daemon
maxconn 250
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
flush
auth strong

users smile:CL:girl

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

####################
eecho "Installing apps ... (yum)"
yum -y install gcc net-tools bsdtar zip wget make

###################
install_3proxy 

# ###################
WORKDIR="$(pwd)/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_
eecho "Working folder = $WORKDIR"

gen_data >$WORKDATA
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
cat >$WORKDIR/boot_3proxy_rc.sh <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 50000
service 3proxy start

# systemctl stop firewalld
# systemctl disable firewalld
# systemctl disable firewalld.service
EOF
chmod +x ${WORKDIR}/boot_*.sh

# qxF match whole line , we dont need it
grep -qF '/boot_3proxy_rc.sh' /etc/rc.local || cat >>/etc/rc.local <<EOF 
bash ${WORKDIR}/boot_3proxy_rc.sh
EOF
chmod +x /etc/rc.local
bash /etc/rc.local

PROXYFILE=proxy.txt
gen_proxy_file >$PROXYFILE
eecho "Done with $PROXYFILE"

zip --password $PROXYPASS proxy.zip $PROXYFILE
URL=$(curl -s --upload-file proxy.zip https://transfer.sh/proxy.zip)

eecho "Proxy is ready! Format IP:PORT:LOGIN:PASS"
eecho "Download zip archive from: ${URL}"
eecho "Password: ${PROXYPASS}"
