#!/bin/bash
location="$1"

if [ -z "$1" ]; then
    echo "`basename $0`: Parameters 1 Required";
    echo "Location:     Location of vm image.";
    exit 1
fi
modprobe nbd max_part=8
qemu-nbd --connect=/dev/nbd0 ${location}
vgchange -ay centos
mkdir $(dirname "${location}")/disk
mount /dev/mapper/centos-root $(dirname "${location}")/disk