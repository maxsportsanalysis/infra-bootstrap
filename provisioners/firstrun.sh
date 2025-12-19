#!/bin/bash

set -e

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

# update-initramfs -u -k 'all'

# -u nautobot /opt/nautobot/bin/nautobot-server init --disable-installation-metrics --config-path /opt/nautobot/nautobot_config.py
runuser -l nautobot -c "/opt/nautobot/bin/nautobot-server init --disable-installation-metrics --config-path /home/nautobot/.nautobot/nautobot_config.py"
systemctl daemon-reload

# --- Cleanup ---
rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0




# sudo -u nautobot /opt/nautobot/bin/nautobot-server init
# step ca init
#/dev/disk/by-uuid/81fd23be-ebc1-4956-86c7-baa1e20bb6bf