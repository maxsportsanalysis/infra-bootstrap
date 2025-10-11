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

  provisioner "file" {
    source      = "provisioners/firstrun.sh"
    destination = "/boot/firmware/firstrun.sh"
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /etc/dnsmasq.d /etc/nginx/sites-available /var/www/html/pxe/ubuntu/ /var/www/html/pxe/rescue"
    ]
  }

  provisioner "file" {
    source      = "configs/dnsmasq.conf"
    destination = "/etc/dnsmasq.d/pxe.conf"
  }

  provisioner "file" {
    source      = "configs/boot.ipxe"
    destination = "/var/www/html/pxe/boot.ipxe"
  }

  provisioner "file" {
    source      = "configs/nginx/pxe.conf"
    destination = "/etc/nginx/sites-available/pxe.conf"
  }

  provisioner "shell" {
    inline = [
      "echo \"${var.rpi_username}:$(openssl passwd -6 '${var.rpi_password}')\" > /boot/firmware/userconf.txt",
      "sed -i 's|$| systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target|' /boot/firmware/cmdline.txt",
      "chmod +x /boot/firmware/firstrun.sh"
    ]
  }

  provisioner "shell" {
    inline = [
      # Create directories
      "mkdir -p /var/www/html/ipxe /var/www/html/pxe/ubuntu/24.04 /var/www/html/pxe/rescue",
      
      # Install dependencies
      "DEBIAN_FRONTEND=noninteractive apt update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq nginx wget",

      # Download iPXE for UEFI
      "wget -q https://boot.ipxe.org/ipxe.efi -O /var/www/html/ipxe/ipxe.efi",

      # Download Ubuntu 24.04 amd64 netboot kernel/initrd
      "wget -q https://releases.ubuntu.com/24.04/netboot/amd64/linux -O /var/www/html/pxe/ubuntu/24.04/vmlinuz",
      "wget -q https://releases.ubuntu.com/24.04/netboot/amd64/initrd.gz -O /var/www/html/pxe/ubuntu/24.04/initrd",

      # Enable & restart services
      "systemctl enable dnsmasq || true",
      "systemctl restart dnsmasq || true",
      "systemctl enable nginx || true",
      "systemctl restart nginx || true"
    ]
  }

}
