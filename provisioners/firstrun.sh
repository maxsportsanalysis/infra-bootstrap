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

systemctl enable dnsmasq || true
systemctl restart dnsmasq || true
systemctl enable nginx || true
systemctl restart nginx || true

# --- Cleanup ---
rm -f /boot/firstrun.sh
rm -f /usr/sbin/policy-rc.d
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0