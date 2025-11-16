#!/bin/bash
set -euo pipefail

# Usage:
#   ./generate_keyfile.sh /root/luks-keyfile
#
# If no argument provided, default to /root/luks-keyfile

EXISTING_LUKS_PASSPHRASE="${EXISTING_LUKS_PASSPHRASE:?Must set EXISTING_LUKS_PASSPHRASE}"
LUKS_DEVICE="${LUKS_DEVICE:?Must set LUKS_DEVICE (ex: /dev/disk/by-uuid/xxxx)}"
LUKS_KEYFILE_PATH="${LUKS_KEYFILE_PATH:?Must set LUKS_KEYFILE_PATH}"
CRYPTTAB_PATH="/etc/crypttab"
LUKS_MAPPER_NAME="${LUKS_MAPPER_NAME:?Must set LUKS_MAPPER_NAME}"
CRYPTTAB_OPTIONS="${CRYPTTAB_OPTIONS:-luks}"

echo "Using keyfile path: $LUKS_KEYFILE_PATH"

# Check if LUKS keyfile exists
if [ -f "$LUKS_KEYFILE_PATH" ]; then
    echo "LUKS keyfile already exists: $LUKS_KEYFILE_PATH"
    exit 0
else
    echo "Generating new 32-byte LUKS keyfile..."
    dd if=/dev/urandom of="$LUKS_KEYFILE_PATH" bs=32 count=1 status=none

    if [ $? -eq 0 ]; then
        chmod 600 "$LUKS_KEYFILE_PATH"
        echo "New LUKS keyfile generated at $LUKS_KEYFILE_PATH"
    else
        echo "ERROR: Failed to generate LUKS keyfile." >&2
        exit 1
    fi
fi

# -----------------------------
# Add the keyfile as a new LUKS key slot
# -----------------------------
echo "Adding keyfile to LUKS header for $LUKS_DEVICE ..."
echo -n "$EXISTING_LUKS_PASSPHRASE" | cryptsetup luksAddKey "$LUKS_DEVICE" "$LUKS_KEYFILE_PATH" --key-file=-

echo "LUKS keyfile added successfully."

# -----------------------------
# Backup /etc/crypttab
# -----------------------------
if [ -f "$CRYPTTAB_PATH" ]; then
    echo "Backing up $CRYPTTAB_PATH to $CRYPTTAB_PATH.bak"
    cp "$CRYPTTAB_PATH" "$CRYPTTAB_PATH.bak"
fi

# -----------------------------
# Update /etc/crypttab
# -----------------------------
DEVICE_UUID=$(basename "$LUKS_DEVICE")  # Extract UUID from /dev/disk/by-uuid/<uuid>

# crypttab line format:
# mapper_name  UUID=<uuid>  <keyfile_path>  <options>
NEW_LINE="$LUKS_MAPPER_NAME UUID=$DEVICE_UUID $LUKS_KEYFILE_PATH $CRYPTTAB_OPTIONS"

echo "Ensuring crypttab contains correct entry..."

# If entry exists, replace it; otherwise, append
if grep -q "^${LUKS_MAPPER_NAME}\b" "$CRYPTTAB_PATH"; then
    # Replace existing line
    sed -i "s|^${LUKS_MAPPER_NAME}.*|$NEW_LINE|" "$CRYPTTAB_PATH"
else
    # Add new line
    echo "$NEW_LINE" >> "$CRYPTTAB_PATH"
fi

echo "/etc/crypttab updated: $NEW_LINE"

echo "Done."





























set -e

UUID="{{ luks_partition_uuid }}"
MAPPER_NAME="{{ luks_mapper_name }}"
KEYFILE="{{ luks_keyfile_path }}"
USE_KEYFILE={{ 'true' if luks_unlock_keyfile else 'false' }}

# Check if already unlocked
if [ -e /dev/mapper/${MAPPER_NAME} ]; then
  echo "Device /dev/mapper/${MAPPER_NAME} already exists, skipping unlock."
  exit 0
fi

# Find device by UUID
DEV=$(blkid -U $UUID)

if [ -z "$DEV" ]; then
  echo "ERROR: Device with UUID $UUID not found!"
  exit 1
fi

if [ "$USE_KEYFILE" == "true" ]; then
  cryptsetup luksOpen "$DEV" "$MAPPER_NAME" --key-file "$KEYFILE"
else
  cryptsetup luksOpen "$DEV" "$MAPPER_NAME"
fi

echo "Device unlocked as /dev/mapper/${MAPPER_NAME}"