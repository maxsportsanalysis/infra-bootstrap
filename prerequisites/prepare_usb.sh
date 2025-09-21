#!/bin/sh

sudo dd if=/dev/zero of=/dev/sdc bs=1M

sudo cryptsetup open /dev/sdc myusb

# lsblk

sudo mkfs.ext4 /dev/mapper/myusb

sudo mount /dev/mapper/myusb /mnt/tmp

sudo umount /mnt/tmp
sudo cryptsetup close myusb