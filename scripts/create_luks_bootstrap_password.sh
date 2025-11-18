#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Usage and argument parsing
###############################################################################
usage() {
  cat <<EOF
Usage: sudo $0 /dev/sdX --name NAME --passfile FILENAME --mapping MAPPING_NAME [--zero]

  /dev/sdX             Block device to prepare (e.g. /dev/sdc)
  --name NAME          Label + mount name (e.g. LUKS_PASSWORD)
  --passfile FILENAME  Name of passphrase file stored on USB
  --mapping NAME       LUKS mapping name used with cryptsetup
  --zero               Optional slow full zero-fill of the device

Example:
  sudo $0 /dev/sdc --name LUKS_PASSWORD --passfile luks.txt --mapping LUKS_VOL
  sudo $0 /dev/sdd --name BACKUP --passfile key.txt --mapping ENC --zero
EOF
  exit 1
}

if [[ $# -lt 7 ]]; then
  usage
fi

DEVICE=""
NAME=""
PASSFILE=""
MAPPING=""
ZERO_WIPE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    /dev/*)
      DEVICE="$1"
      shift
      ;;
    --name)
      NAME="$2"
      shift 2
      ;;
    --passfile)
      PASSFILE="$2"
      shift 2
      ;;
    --mapping)
      MAPPING="$2"
      shift 2
      ;;
    --zero)
      ZERO_WIPE=true
      shift
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$DEVICE" || -z "$NAME" || -z "$PASSFILE" || -z "$MAPPING" ]]; then
  echo "ERROR: Missing required arguments."
  usage
fi

###############################################################################
# Root + safety
###############################################################################
die() { echo "ERROR: $*"; exit 1; }
info() { echo "=> $*"; }

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  die "This script must be run as root."
fi

if [[ ! -b "$DEVICE" ]]; then
  die "$DEVICE is not a block device."
fi

DEVICE="$(readlink -f "$DEVICE")"

NAME_UPPER=$(echo "$NAME" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9_-')
MOUNT_POINT="/mnt/${NAME_UPPER}"
FILESYSTEM_LABEL="$NAME_UPPER"
MIN_DEVICE_SIZE_MB=30

###############################################################################
# Confirm destructive operation
###############################################################################
DEV_SIZE_BYTES=$(blockdev --getsize64 "$DEVICE")
DEV_SIZE_MB=$(( DEV_SIZE_BYTES / 1024 / 1024 ))
info "Device: $DEVICE ($DEV_SIZE_MB MiB)"

if (( DEV_SIZE_MB < MIN_DEVICE_SIZE_MB )); then
  die "Device too small (< ${MIN_DEVICE_SIZE_MB}MB)."
fi

read -rp "⚠️  ALL DATA on $DEVICE will be destroyed. Continue? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || die "Aborted."

###############################################################################
# Unmount previous mounts
###############################################################################
info "Unmounting any mounts for $DEVICE..."

mapfile -t MOUNTS < <(findmnt -rn -S "$DEVICE" -o TARGET || true)
for m in "${MOUNTS[@]:-}"; do
  info "Unmounting $m"
  umount -l "$m" || true
done

for p in $(ls "${DEVICE}"* 2>/dev/null || true); do
  mapfile -t PM < <(findmnt -rn -S "$p" -o TARGET || true)
  for m in "${PM[@]:-}"; do
    info "Unmounting partition $m"
    umount -l "$m" || true
  done
done

###############################################################################
# Optional zero wipe
###############################################################################
if $ZERO_WIPE; then
  info "Zero-filling device (slow)..."
  dd if=/dev/zero of="$DEVICE" bs=4M status=progress conv=fsync || true
  sync
fi

###############################################################################
# Partition + format
###############################################################################
info "Wiping filesystem signatures..."
wipefs -a "$DEVICE"

info "Creating GPT + single full-size partition..."
sgdisk --zap-all "$DEVICE"
parted --script "$DEVICE" mklabel gpt mkpart primary 0% 100%
sleep 1

PARTITION="$(ls ${DEVICE}* | grep -E "^${DEVICE}p?1$" | head -n1)"
[[ -z "$PARTITION" ]] && die "Partition creation failed."

info "Formatting $PARTITION as ext4 (label=$FILESYSTEM_LABEL)..."
mkfs.ext4 -L "$FILESYSTEM_LABEL" "$PARTITION"

mkdir -p "$MOUNT_POINT"
mount "$PARTITION" "$MOUNT_POINT"
info "Mounted at: $MOUNT_POINT"

###############################################################################
# Collect passphrase and write it onto USB
###############################################################################
PASSFILE_PATH="$MOUNT_POINT/$PASSFILE"

if [[ -e "$PASSFILE_PATH" ]]; then
  die "Passphrase file already exists: $PASSFILE_PATH"
fi

echo -n "Enter LUKS passphrase for mapping '$MAPPING': "
read -rs LUKS_PASSPHRASE
echo

[[ -z "$LUKS_PASSPHRASE" ]] && die "Passphrase cannot be empty."

echo -n "$LUKS_PASSPHRASE" > "$PASSFILE_PATH"
chmod 600 "$PASSFILE_PATH"

###############################################################################
# Finish
###############################################################################
cat <<EOF

✔ USB fully prepared.
✔ LUKS passphrase written to: $PASSFILE_PATH

Summary:
  Device:        $DEVICE
  Partition:     $PARTITION
  Mount:         $MOUNT_POINT
  Label:         $FILESYSTEM_LABEL
  Passphrase:    $PASSFILE
  Mapping name:  $MAPPING

To unmount:
  sudo umount $MOUNT_POINT

EOF