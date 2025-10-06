#!/bin/bash

set +e
echo "==== firstrun.sh starting at $(date) ===="

# --- Variables from packer (templated in) ---
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

# --- Hostname setup ---
CURRENT_HOSTNAME=$(tr -d " \t\n\r" < /etc/hostname)
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
  /usr/lib/raspberrypi-sys-mods/imager_custom set_hostname "$HOSTNAME"
else
  echo "$HOSTNAME" > /etc/hostname
  sed -i "s/127\.0\.1\.1.*$CURRENT_HOSTNAME/127.0.1.1\t$HOSTNAME/g" /etc/hosts
fi

# --- User setup ---
FIRSTUSER=$(getent passwd 1000 | cut -d: -f1)
FIRSTUSERHOME=$(getent passwd 1000 | cut -d: -f6)

# Use userconf if available (on newer Raspberry Pi OS versions)
if [ -f /usr/lib/userconf-pi/userconf ]; then
  # userconf expects plaintext, but we only have a hash.
  # Instead, we'll use chpasswd -e directly below.
  echo "userconf detected, skipping (hash mode)..."
fi

# Apply password hash directly
echo "$FIRSTUSER:$PASSWORD_HASH" | chpasswd -e

# If FIRSTUSER name differs from desired username, rename and fix references
if [ "$FIRSTUSER" != "$USERNAME" ]; then
  usermod -l "$USERNAME" "$FIRSTUSER"
  usermod -m -d "/home/$USERNAME" "$USERNAME"
  groupmod -n "$USERNAME" "$FIRSTUSER"

  # Update autologin/lightdm if present
  if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf 2>/dev/null; then
    sed -i -E "s/^autologin-user=.*/autologin-user=$USERNAME/" /etc/lightdm/lightdm.conf
  fi
  if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
    sed -i "s/$FIRSTUSER/$USERNAME/" /etc/systemd/system/getty@tty1.service.d/autologin.conf
  fi
  if [ -f /etc/sudoers.d/010_pi-nopasswd ]; then
    sed -i "s/^$FIRSTUSER /$USERNAME /" /etc/sudoers.d/010_pi-nopasswd
  fi
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
