packer {
  required_version = ">= 1.14.0"

  required_plugins {
    arm-image = {
      version = ">= 0.2.7"
      source  = "github.com/solo-io/arm-image"
    }
  }
}

variable "iso_url" {
  # Raspberry Pi OS Lite (64-bit) latest
  default = "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64-lite.img.xz"
}

variable "iso_checksum" {
  # Replace with the actual SHA256 from Raspberry Pi's site
  default = "sha256:62d025b9bc7ca0e1facfec74ae56ac13978b6745c58177f081d39fbb8041ed45"
}

variable "image_path" {
  default = "raspios-lite-arm64.img"
}

source "arm-image" "raspberry_pi_os" {
  iso_urls        = [var.iso_url]
  iso_checksum    = var.iso_checksum
  output_filename = var.image_path
  qemu_binary     = "qemu-aarch64-static"

  # Always mount both partitions to avoid "rootfs missing" issues
  image_mounts = [
    "/boot/firmware",
    "/"
  ]
}

build {
  name    = "raspios-arm64-ssh"
  sources = ["source.arm-image.raspberry_pi_os"]

  # Enable SSH at first boot
  provisioner "shell" {
    inline = [
      "touch /boot/ssh"
    ]
  }
}
