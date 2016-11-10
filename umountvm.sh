#!/bin/bash
location="$1"

if [ -z "$1" ]; then
    echo "`basename $0`: Parameters 1 Required";
    echo "Location:     Location of vm image.";
    exit 1
fi
umount $(dirname "${location}")/disk
vgchange -an centos
qemu-nbd -d /dev/nbd0
rm -r $(dirname "${location}")/disk
