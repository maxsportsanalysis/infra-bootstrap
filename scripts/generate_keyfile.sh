#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 /mnt/usb_mount_path filename"
  echo "Example: $0 /mnt/LUKS_PASSWORD luks_keyfile"
  exit 1
fi

MOUNT_PATH="$1"
KEYFILE_NAME="$2"
KEYFILE_PATH="${MOUNT_PATH}/${KEYFILE_NAME}"

if [[ ! -d "$MOUNT_PATH" ]]; then
  echo "ERROR: Mount path $MOUNT_PATH does not exist or is not a directory"
  exit 1
fi

if [[ -e "$KEYFILE_PATH" ]]; then
  echo "ERROR: Keyfile $KEYFILE_PATH already exists, aborting to avoid overwrite"
  exit 1
fi

echo "Generating 32-byte random LUKS keyfile at $KEYFILE_PATH..."

# Generate keyfile
dd if=/dev/urandom of="$KEYFILE_PATH" bs=32 count=1 status=none

# Restrict permissions
chmod 600 "$KEYFILE_PATH"

echo "Keyfile generated and permissions set to 600."

echo "Verify keyfile:"
ls -l "$KEYFILE_PATH"

echo "Done."