#!/bin/bash
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