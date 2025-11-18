#!/bin/bash

set -e

echo "==== firstrun.sh starting at $(date) ===="

LUKS_DEVICE="/dev/disk/by-uuid/64295905-56a0-4b43-bbaa-540492146dce"
CLEVIS_PIN="tang"
TANG_URL="http://localhost"
# Adjust your mapping name and device path as needed
MAPPER_NAME="luksmapper"


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

#/usr/libexec/tangd-keygen /var/db/tang

# --- Cleanup ---
rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0




# sudo -u nautobot /opt/nautobot/bin/nautobot-server init
# step ca init
#/dev/disk/by-uuid/81fd23be-ebc1-4956-86c7-baa1e20bb6bf