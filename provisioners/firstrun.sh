#!/bin/bash
set -e

echo "==== firstrun.sh starting at $(date) ===="

# --- Variables from Packer ---
USERNAME="${RPI_USERNAME}"
HOSTNAME="${RPI_HOSTNAME}"
KEYMAP="${RPI_KEYMAP:-us}"
TIMEZONE="${RPI_TIMEZONE:-America/Chicago}"
PWHASH_FILE="/etc/firstboot/pwhash"

# --- Verify password hash file ---
if [ ! -f "$PWHASH_FILE" ]; then
  echo "ERROR: Password hash file not found at $PWHASH_FILE" >&2
  exit 1
fi
chmod 600 "$PWHASH_FILE"
PASSWORD_HASH=$(head -n1 "$PWHASH_FILE" | tr -d '\r\n')

# --- Create /boot/userconf to auto-configure user on first boot ---
mkdir -p /boot
echo "${USERNAME}:${PASSWORD_HASH}" > /boot/userconf
chmod 600 /boot/userconf

# --- Hostname setup ---
CURRENT_HOSTNAME=$(tr -d " \t\n\r" < /etc/hostname)
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
  /usr/lib/raspberrypi-sys-mods/imager_custom set_hostname "$HOSTNAME"
else
  echo "$HOSTNAME" > /etc/hostname
  sed -i "s/127\.0\.1\.1.*$CURRENT_HOSTNAME/127.0.1.1\t$HOSTNAME/g" /etc/hosts
fi

# --- Keyboard + timezone ---
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
  /usr/lib/raspberrypi-sys-mods/imager_custom set_keymap "$KEYMAP"
  /usr/lib/raspberrypi-sys-mods/imager_custom set_timezone "$TIMEZONE"
else
  rm -f /etc/localtime
  echo "$TIMEZONE" > /etc/timezone
  dpkg-reconfigure -f noninteractive tzdata

  cat >/etc/default/keyboard <<KBEOF
XKBMODEL="pc105"
XKBLAYOUT="$KEYMAP"
XKBVARIANT=""
XKBOPTIONS=""
KBEOF
  dpkg-reconfigure -f noninteractive keyboard-configuration
fi

# --- Cleanup ---
rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt

echo "==== firstrun.sh completed successfully ===="
exit 0