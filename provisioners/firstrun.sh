#!/bin/bash

set -e

STEP_CA_DIR="/var/lib/step-ca"
STEP_CA_CONFIG="$STEP_CA_DIR/config/ca.json"
PASSWORD_FILE="/root/step-ca-password.txt"
PROVISIONER_PASSWORD_FILE="/root/step-ca-provisioner-password.txt"

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

# --- Generate random passwords if they don't exist ---
#if [ ! -f "$PASSWORD_FILE" ]; then
#  head -c 32 /dev/urandom | base64 > "$PASSWORD_FILE"
#  chmod 600 "$PASSWORD_FILE"
#  echo "Generated new CA password"
#fi
#
#if [ ! -f "$PROVISIONER_PASSWORD_FILE" ]; then
#  head -c 32 /dev/urandom | base64 > "$PROVISIONER_PASSWORD_FILE"
#  chmod 600 "$PROVISIONER_PASSWORD_FILE"
#  echo "Generated new provisioner password"
#fi
#
## --- Initialize step-ca if not initialized ---
#if [ ! -f "$STEP_CA_CONFIG" ]; then
#  echo "Initializing step-ca CA..."
#  step ca init \
#    --name "Internal CA" \
#    --dns "ca.internal" \
#    --address ":443" \
#    --provisioner admin \
#    --password-file "$PASSWORD_FILE" \
#    --provisioner-password-file "$PROVISIONER_PASSWORD_FILE"
#  echo "step-ca initialization complete."
#else
#  echo "step-ca already initialized."
#fi

# --- Cleanup ---
rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0