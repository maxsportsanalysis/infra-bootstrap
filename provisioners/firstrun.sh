#!/bin/bash
set -euxo pipefail

exec > >(tee -a /var/log/firstrun.log) 2>&1
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

# Wait for network
until ping -c1 archive.raspberrypi.org &>/dev/null; do
    echo "Waiting for network..."
    sleep 3
done

# --- Install packages ---
apt update
apt install -y dnsmasq nginx wget

# --- Setup iPXE / netboot ---
mkdir -p /var/www/html/ipxe /var/www/html/pxe/ubuntu/22.04 /var/www/html/pxe/rescue
wget -q https://boot.ipxe.org/ipxe.efi -O /var/www/html/ipxe/ipxe.efi
wget -q https://cdimage.ubuntu.com/releases/24.04/release/netboot/arm64/linux -O /var/www/html/pxe/ubuntu/22.04/vmlinuz
wget -q https://cdimage.ubuntu.com/releases/24.04/release/netboot/arm64/initrd.gz -O /var/www/html/pxe/ubuntu/22.04/initrd.gz

# --- Enable services ---
systemctl enable dnsmasq
systemctl restart dnsmasq
systemctl enable nginx
systemctl restart nginx

# --- Cleanup ---
rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt

echo "==== firstrun.sh finished at $(date) ===="
exit 0
