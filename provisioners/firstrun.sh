#!/bin/bash

set +e

echo "==== firstrun.sh starting at $(date) ===="

# --- Keyboard + timezone ---
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
   /usr/lib/raspberrypi-sys-mods/imager_custom set_keymap "us"
   /usr/lib/raspberrypi-sys-mods/imager_custom set_timezone "UTC"
else
   rm -f /etc/localtime
   echo "UTC" >/etc/timezone
   dpkg-reconfigure -f noninteractive tzdata
cat >/etc/default/keyboard <<KBEOF
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""
KBEOF
   dpkg-reconfigure -f noninteractive keyboard-configuration
fi

PXE_IP=$(hostname -I | awk '{print $1}')

sed -i "s|\${pxe_server_ip}|${PXE_IP}|g" /srv/tftpboot/pxelinux.cfg/default
sed -i "s|\${pxe_server_ip}|${ESCAPED_PXE_IP}|g" /etc/dnsmasq.d/pxe.conf

# --- Cleanup ---
rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0