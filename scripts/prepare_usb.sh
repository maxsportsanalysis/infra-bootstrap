#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: sudo $0 /dev/sdX --name NAME [--zero]

  /dev/sdX           Block device to prepare (e.g. /dev/sdc)
  --name NAME        Logical device name (e.g. ROOT_CA, INTERMEDIATE_CA) used in labels and mount points
  --zero             (optional) Perform full dd zero-fill before other steps (slow)

Example:
  sudo $0 /dev/sdc --name ROOT_CA
  sudo $0 /dev/sdd --name INTERMEDIATE_CA --zero
EOF
  exit 1
}

if [[ $# -lt 3 ]]; then
  usage
fi

DEVICE=""
NAME=""
ZERO_WIPE=false

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    /dev/*)
      if [[ -n "$DEVICE" ]]; then
        echo "ERROR: Device specified multiple times."
        usage
      fi
      DEVICE="$1"
      shift
      ;;
    --name)
      if [[ -n "$NAME" ]]; then
        echo "ERROR: Name specified multiple times."
        usage
      fi
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --name requires an argument."
        usage
      fi
      NAME="$2"
      shift 2
      ;;
    --zero)
      ZERO_WIPE=true
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
done

if [[ -z "$DEVICE" || -z "$NAME" ]]; then
  echo "ERROR: Device and --name are required."
  usage
fi

# Normalize NAME to uppercase and remove spaces for safety
NAME_UPPER=$(echo "$NAME" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9_-')

DEVICE_BASENAME="$(basename "$DEVICE")"
MAPPER_NAME="${NAME_UPPER}"
MOUNT_POINT="/mnt/${MAPPER_NAME}"
FILESYSTEM_LABEL="${NAME_UPPER}"
MIN_DEVICE_SIZE_MB=30    # refuse devices smaller than this (safety)

die() { echo "ERROR: $*"; exit 1; }
info() { echo "=> $*"; }

require_root() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    die "This script must be run as root. Try: sudo $0 $*"
  fi
}

require_root

# -------------------------
# Validations
# -------------------------
if [[ ! -b "$DEVICE" ]]; then
  die "$DEVICE is not a block device."
fi

DEVICE="$(readlink -f "$DEVICE")"

DEV_SIZE_BYTES=$(blockdev --getsize64 "$DEVICE" 2>/dev/null || echo 0)
DEV_SIZE_MB=$(( DEV_SIZE_BYTES / 1024 / 1024 ))
info "Device: $DEVICE ($DEV_SIZE_MB MiB)"

if (( DEV_SIZE_MB > 0 )) && (( DEV_SIZE_MB < MIN_DEVICE_SIZE_MB )); then
  die "Refusing: device appears very small (${DEV_SIZE_MB} MiB). If you really want to continue, lower MIN_DEVICE_SIZE_MB in the script."
fi

read -rp "⚠️  THIS WILL ERASE ALL DATA on $DEVICE. Continue? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || die "Aborted by user."

# -------------------------
# Clean up mounts / LUKS mappings
# -------------------------
info "Cleaning up mounts and LUKS mappings for $DEVICE ..."

mapfile -t MOUNTS < <(findmnt -rn -S "$DEVICE" -o TARGET || true)
for m in "${MOUNTS[@]:-}"; do
  info "Unmounting $m"
  umount -l "$m" || true
done

for p in $(ls "${DEVICE}"* 2>/dev/null || true); do
  mapfile -t PM < <(findmnt -rn -S "$p" -o TARGET || true)
  for m in "${PM[@]:-}"; do
    info "Unmounting partition mount $m (for $p)"
    umount -l "$m" || true
  done
done

for attempt in 1 2 3; do
  CLOSED_ANY=false
  while read -r mapper_line; do
    mapper=$(awk '{print $1}' <<<"$mapper_line")
    if cryptsetup status "$mapper" 2>/dev/null | grep -q "$DEVICE"; then
      info "Found mapper $mapper referencing $DEVICE - attempting to close"
      MNTS=$(findmnt -rn -S "/dev/mapper/$mapper" -o TARGET || true)
      for m in $MNTS; do
        umount -l "$m" || true
      done
      cryptsetup luksClose "$mapper" 2>/dev/null || true
      dmsetup remove "$mapper" 2>/dev/null || true
      CLOSED_ANY=true
    fi
  done < <(dmsetup ls --target crypt 2>/dev/null || true)

  if ! $CLOSED_ANY; then
    break
  fi
  sleep 1
done

if lsof "$DEVICE" &>/dev/null; then
  info "Processes hold $DEVICE; attempting to terminate them..."
  lsof -t "$DEVICE" | xargs -r kill -9 || true
  sleep 1
fi

partprobe "$DEVICE" || true
sleep 1

if findmnt -rn -S "$DEVICE" >/dev/null || dmsetup ls --target crypt | grep -q .; then
  info "Verification: current lsblk:"
  lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT
fi

# -------------------------
# Optional zero wipe
# -------------------------
if $ZERO_WIPE; then
  info "Zero-filling entire device (this can take a long time)..."
  dd if=/dev/zero of="$DEVICE" bs=4M status=progress conv=fsync || true
  sync
  partprobe "$DEVICE" || true
fi

# -------------------------
# Partition and format
# -------------------------
info "Erasing filesystem signatures and partition table..."
wipefs -a "$DEVICE" || true
sgdisk --zap-all "$DEVICE" || true

info "Creating new GPT label and single partition..."
parted --script "$DEVICE" mklabel gpt mkpart primary 0% 100%
sleep 1

PARTITION="$(ls ${DEVICE}* 2>/dev/null | grep -E "^${DEVICE}p?1$" | head -n1 || true)"
if [[ -z "$PARTITION" ]]; then
  die "Failed to locate the partition after parted. Aborting."
fi
info "Using partition: $PARTITION"

info "Setting up LUKS2 on $PARTITION (you will be prompted for a passphrase)..."
cryptsetup luksFormat --type luks2 "$PARTITION"

info "Opening LUKS container as /dev/mapper/$MAPPER_NAME ..."
cryptsetup open "$PARTITION" "$MAPPER_NAME"

info "Creating ext4 filesystem (label=${FILESYSTEM_LABEL})..."
mkfs.ext4 -L "$FILESYSTEM_LABEL" "/dev/mapper/$MAPPER_NAME"

mkdir -p "$MOUNT_POINT"
mount "/dev/mapper/$MAPPER_NAME" "$MOUNT_POINT"

info "Done. Mounted at: $MOUNT_POINT"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT | sed -n '1,200p'

cat <<EOF

✔ USB prepared successfully.

Details:
  Device:        $DEVICE
  Partition:     $PARTITION
  Mapper:         /dev/mapper/$MAPPER_NAME
  Mount point:   $MOUNT_POINT
  Filesystem:    ext4 (label=$FILESYSTEM_LABEL)

When finished, unmount & close with:
  sudo umount $MOUNT_POINT
  sudo cryptsetup luksClose $MAPPER_NAME

Quick unmount helper (save as unmount_usb.sh):
  #!/usr/bin/env bash
  set -euo pipefail
  sudo umount -l "$MOUNT_POINT" || true
  sudo cryptsetup luksClose "$MAPPER_NAME" || true

EOF