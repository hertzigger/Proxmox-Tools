#!/bin/bash
IP="$1"
location="$2"
if [ -z "$1" ]; then
    echo "`basename $0`: Parameters 1 Required";
    echo "IP:           last 2 octets of new ip.";
    echo "Location:     location of VM template.";
    exit 1
fi
sed -i s/^IPADDR.*/IPADDR=\"172.16.${IP}\"/ $(dirname "${location}")/disk/etc/sysconfig/network-scripts/ifcfg-ens18
sed -i s/^IPADDR.*/IPADDR=\"192.168.${IP}\"/ $(dirname "${location}")/disk/etc/sysconfig/network-scripts/ifcfg-ens19