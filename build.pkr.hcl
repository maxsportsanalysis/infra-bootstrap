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
  type = string
  description = "URL to the OS image."
  default = null
}

variable "iso_checksum" {
  type = string
  description = "Checksum of the image, with type prefix (e.g. sha256:)."
  default = null
}

variable "image_path" {
  type = string
  default = null
}

variable "qemu_binary" {
  type = string
  default = "qemu-arm-static"
  description = "Qemu binary to use. If this is an absolute path, it will be used. Otherwise, we will look for one in your PATH and finally, try to auto fetch one from https://github.com/multiarch/qemu-user-static/"
}

variable "image_mounts" {
  type    = list(string)
  description = "Where to mounts the image partitions in the chroot. first entry is the mount point of the first partition. etc.."
  default = []
}

variable "chroot_mounts" {
  type    = list(list(string))
  description = "What directories mount from the host to the chroot. leave it empty for reasonable defaults. array of triplets: [type, device, mntpoint]."
  default = []
}

variable "rpi_hostname" {
  type        = string
  description = "Default hostname for Raspberry Pi"
  default     = "pxe-bootstrap"
}

variable "rpi_username" {
  type      = string
  description = "Username for Raspberry Pi"
  sensitive = true
}

variable "rpi_password" {
  type      = string
  description = "Password for Raspberry Pi"
  sensitive = true
}

source "arm-image" "raspberry_pi_os" {
  iso_urls        = [var.iso_url]
  iso_checksum    = var.iso_checksum
  output_filename = var.image_path
  qemu_binary     = var.qemu_binary

  image_mounts = var.image_mounts

  chroot_mounts = var.chroot_mounts
}

build {
  name    = "raspios-arm64-prod"
  sources = ["source.arm-image.raspberry_pi_os"]

  # Enable SSH
  provisioner "file" {
    source      = "/dev/null"
    destination = "/boot/firmware/ssh"
  }

  # Drop first-run provisioning script
  provisioner "file" {
    source      = "provisioners/firstrun.sh"
    destination = "/boot/firmware/firstrun.sh"
  }

  # Patch cmdline.txt so firstrun.sh executes
  provisioner "shell" {
    environment_vars = [
      "RPI_USERNAME=${var.rpi_username}",
      "RPI_PASSWORD=${var.rpi_password}",
      "RPI_HOSTNAME=${var.rpi_hostname}"
    ]

    inline = [
      "sed -i 's|$| systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target|' /boot/firmware/cmdline.txt"
    ]
  }
}
