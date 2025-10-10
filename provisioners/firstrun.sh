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

mkdir -p /var/www/html/ipxe /var/www/html/pxe/ubuntu/22.04 /var/www/html/pxe/rescue
DEBIAN_FRONTEND=noninteractive apt update
DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq nginx wget

# Download iPXE for UEFI
wget -q https://boot.ipxe.org/ipxe.efi -O /var/www/html/ipxe/ipxe.efi

# Download Ubuntu netboot kernel/initrd
wget -q https://cdimage.ubuntu.com/releases/24.04/release/netboot/arm64/linux -O /var/www/html/pxe/ubuntu/22.04/vmlinuz
wget -q https://cdimage.ubuntu.com/releases/24.04/release/netboot/arm64/initrd.gz -O /var/www/html/pxe/ubuntu/22.04/initrd.gz

systemctl enable dnsmasq || true
systemctl restart dnsmasq || true
systemctl enable nginx || true
systemctl restart nginx || true

# --- Cleanup ---
rm -f /boot/firstrun.sh
rm -f /usr/sbin/policy-rc.d
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0