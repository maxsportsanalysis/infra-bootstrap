# pi.auto.pkrvars.hcl

iso_url = "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64-lite.img.xz"
iso_checksum = "sha256:62d025b9bc7ca0e1facfec74ae56ac13978b6745c58177f081d39fbb8041ed45"
image_path = "raspios-lite-arm64.img"
qemu_binary = "qemu-aarch64-static"
image_mounts = ["/boot/firmware","/"]
chroot_mounts = [
    ["proc", "proc", "/proc"],
    ["sysfs", "sysfs", "/sys"],
    ["bind", "/dev", "/dev"],
    ["devpts", "devpts", "/dev/pts"],
    ["binfmt_misc", "binfmt_misc", "/proc/sys/fs/binfmt_misc"]
  ]
rpi_hostname = "pxe-bootstrap"