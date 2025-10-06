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
}

variable "iso_checksum" {
  type = string
  description = "Checksum of the image, with type prefix (e.g. sha256:)."
}

variable "image_path" {
  type = string
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

variable "pwhash_src" {
  type      = string
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

  provisioner "file" {
    # local source on the packer runner (create it in GitHub Actions)
    source      = "build/secrets/pwhash"
    destination = "/etc/firstboot/pwhash"
  }


  provisioner "file" {
    source      = "provisioners/firstrun.sh"
    destination = "/boot/firmware/firstrun.sh"
  }

  provisioner "shell" {

    inline = [
      "sed -i 's|$| systemd.run=/boot/firstrun.sh --username ${var.rpi_username} --password ${var.rpi_password} systemd.run_success_action=reboot systemd.unit=kernel-command-line.target|' /boot/firmware/cmdline.txt",
      "chmod +x /boot/firmware/firstrun.sh",
      "sed -i 's|RPI_USERNAME=.*|RPI_USERNAME=${var.rpi_username}|' /boot/firmware/firstrun.sh",
      "sed -i 's|RPI_PASSWORD=.*|RPI_PASSWORD=${var.rpi_password}|' /boot/firmware/firstrun.sh",
      "sed -i 's|RPI_HOSTNAME=.*|RPI_HOSTNAME=${var.rpi_hostname}|' /boot/firmware/firstrun.sh"
    ]
  }
}
