#!/bin/sh

sudo dd if=/dev/zero of=/dev/sdc bs=1M

sudo cryptsetup open /dev/sdc myusb

# lsblk

sudo mkfs.ext4 /dev/mapper/myusb

sudo mount /dev/mapper/myusb /mnt/tmp

sudo umount /mnt/tmp
sudo cryptsetup close myusb

=============================================

#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG ---
MAPPER_NAME="secure_usb"
MOUNT_POINT="/mnt/$MAPPER_NAME"

# --- FUNCTIONS ---
confirm() {
    read -r -p "$1 [y/N]: " response
    [[ "$response" =~ ^[Yy]$ ]]
}

# --- STEP 1: Detect devices ---
echo "Available storage devices:"
lsblk -dpno NAME,SIZE,MODEL | grep -v "loop"
echo
read -rp "Enter device path (e.g. /dev/sdc): " DEVICE

if [ ! -b "$DEVICE" ]; then
  echo "❌ Error: $DEVICE is not a valid block device."
  exit 1
fi

# --- STEP 2: Confirm destruction ---
echo "⚠️  WARNING: This will ERASE ALL DATA on $DEVICE!"
confirm "Are you sure you want to continue?" || exit 1

# --- STEP 3: Zero out device ---
echo "🧹 Wiping $DEVICE..."
sudo dd if=/dev/zero of="$DEVICE" bs=1M status=progress || true
sync

# --- STEP 4: Create LUKS container ---
echo "🔐 Setting up LUKS encryption on $DEVICE..."
sudo cryptsetup luksFormat "$DEVICE"  # <-- will prompt for passphrase interactively
sudo cryptsetup open "$DEVICE" "$MAPPER_NAME"

# --- STEP 5: Create filesystem ---
echo "📦 Formatting encrypted volume with ext4..."
sudo mkfs.ext4 /dev/mapper/"$MAPPER_NAME"

# --- STEP 6: Mount, verify, and unmount ---
sudo mkdir -p "$MOUNT_POINT"
sudo mount /dev/mapper/"$MAPPER_NAME" "$MOUNT_POINT"
echo "✅ Mounted at $MOUNT_POINT"
lsblk | grep "$MAPPER_NAME"

# Pause to confirm everything looks good
confirm "Unmount and close device?" && {
  sudo umount "$MOUNT_POINT"
  sudo cryptsetup close "$MAPPER_NAME"
  echo "🔒 Drive closed and ready."
}

echo "✅ Done! You can now safely remove or reuse $DEVICE."
