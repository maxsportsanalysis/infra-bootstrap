#!/bin/bash

set +e

# --- Variables from packer (templated in) ---
USERNAME="${RPI_USERNAME:-mcilek}"
PASSWORD="${RPI_PASSWORD}"
HOSTNAME="${RPI_HOSTNAME:-maxsportsanalysis-pi}"
KEYMAP="${RPI_KEYMAP:-us}"
TIMEZONE="${RPI_TIMEZONE:-America/Chicago}"

PASSWORD_HASH=$(openssl passwd -6 "$PASSWORD")

# --- Hostname ---
CURRENT_HOSTNAME=$(cat /etc/hostname | tr -d " \t\n\r")
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
   /usr/lib/raspberrypi-sys-mods/imager_custom set_hostname "$HOSTNAME"
else
   echo "$HOSTNAME" >/etc/hostname
   sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$HOSTNAME/g" /etc/hosts
fi

# --- User setup ---
FIRSTUSER=$(getent passwd 1000 | cut -d: -f1)
FIRSTUSERHOME=$(getent passwd 1000 | cut -d: -f6)
if [ -f /usr/lib/userconf-pi/userconf ]; then
   /usr/lib/userconf-pi/userconf "$USERNAME" "$PASSWORD_HASH"
else
   echo "$FIRSTUSER:$PASSWORD_HASH" | chpasswd -e
   if [ "$FIRSTUSER" != "$USERNAME" ]; then
      usermod -l "$USERNAME" "$FIRSTUSER"
      usermod -m -d "/home/$USERNAME" "$USERNAME"
      groupmod -n "$USERNAME" "$FIRSTUSER"
      if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf ; then
         sed /etc/lightdm/lightdm.conf -i -e "s/^autologin-user=.*/autologin-user=$USERNAME/"
      fi
      if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
         sed /etc/systemd/system/getty@tty1.service.d/autologin.conf -i -e "s/$FIRSTUSER/$USERNAME/"
      fi
      if [ -f /etc/sudoers.d/010_pi-nopasswd ]; then
         sed -i "s/^$FIRSTUSER /$USERNAME /" /etc/sudoers.d/010_pi-nopasswd
      fi
   fi
fi

# --- Keyboard + timezone ---
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
   /usr/lib/raspberrypi-sys-mods/imager_custom set_keymap "$KEYMAP"
   /usr/lib/raspberrypi-sys-mods/imager_custom set_timezone "$TIMEZONE"
else
   rm -f /etc/localtime
   echo "$TIMEZONE" >/etc/timezone
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
exit 0
