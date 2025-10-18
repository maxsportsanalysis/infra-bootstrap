packer {
  required_version = ">= 1.14.0"

  required_plugins {
    arm-image = {
      version = ">= 0.2.7"
      source  = "github.com/solo-io/arm-image"
    }
  }
}

variable "chroot_mounts" {
  type        = list(list(string))
  default     = []
  description = "Host directories to mount into the chroot."
}

variable "dhcp_range" {
  type    = string
  default = "0.0.0.0,proxy"
}

variable "image_mounts" {
  type        = list(string)
  default     = []
  description = "Where to mount the image partitions in the chroot."
}

variable "image_path" {
  type        = string
}

variable "iso_checksum" {
  type        = string
  description = "Checksum of the image, with type prefix (e.g., sha256:)."
}

variable "iso_url" {
  type        = string
  description = "URL to the OS image."
}

variable "k8s_ubuntu_version" {
  type        = string
  default     = "24.04.3"
}

variable "pxe_server_ip" {
  type = string
  default = ""
}

variable "qemu_binary" {
  type        = string
  default     = "qemu-arm-static"
  description = "Qemu binary to use."
}

variable "rpi_password" {
  type        = string
  sensitive   = true
}

variable "rpi_username" {
  type        = string
  sensitive   = true
}

variable "tftp_root" {
  type = string
  default = "/srv/tftpboot"
}

source "arm-image" "raspberry_pi_os" {
  iso_urls        = [var.iso_url]
  iso_checksum    = var.iso_checksum
  output_filename = var.image_path
  qemu_binary     = var.qemu_binary
  image_mounts    = var.image_mounts
  chroot_mounts   = var.chroot_mounts
}


locals {
  k8s_iso_url = "https://releases.ubuntu.com/${var.k8s_ubuntu_version}/ubuntu-${var.k8s_ubuntu_version}-live-server-amd64.iso"
}

build {
  name    = "pxe-server-arm64-prod"
  sources = ["source.arm-image.raspberry_pi_os"]

  # Enable SSH on PXE server
  provisioner "file" {
    source      = "/dev/null"
    destination = "/boot/firmware/ssh"
  }

  provisioner "file" {
    source      = "provisioners/firstrun.sh"
    destination = "/boot/firmware/firstrun.sh"
  }

  # Set PXE server SSH credentials
  provisioner "shell" {
    inline = [
      "echo \"${var.rpi_username}:$(openssl passwd -6 '${var.rpi_password}')\" > /boot/firmware/userconf.txt",
      "sed -i 's|$| systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target|' /boot/firmware/cmdline.txt",
      "chmod +x /boot/firmware/firstrun.sh"
    ]
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /etc/nginx/sites-available",
      "mkdir -p /srv/tftpboot/pxelinux.cfg /srv/tftpboot/ubuntu/${var.k8s_ubuntu_version}",
      "mkdir -p /var/www/html/pxe/rescue /var/www/html/ipxe /var/www/html/pxe/ubuntu/${var.k8s_ubuntu_version} /var/www/html/autoinstall"
    ]
  }

  provisioner "file" {
    source      = "configs/nginx/pxe.conf"
    destination = "/etc/nginx/sites-available/pxe.conf"
  }

  provisioner "file" {
    source      = "/dev/null"
    destination = "/var/www/html/autoinstall/vendor-data"
  }

  provisioner "file" {
    source      = "/dev/null"
    destination = "/var/www/html/autoinstall/meta-data"
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /etc/dnsmasq.d",
      <<-EOT
      cat <<EOF >/etc/dnsmasq.d/pxe.conf
      ${templatefile("${path.root}/templates/dnsmasq.pxe.pkrtpl.hcl", {
        dhcp_range     = var.dhcp_range,
        tftp_root      = var.tftp_root,
        pxe_server_ip  = var.pxe_server_ip
      })}
      EOF
      EOT
    ]
  }

  provisioner "file" {
    source      = "templates/boot.ipxe.pkrtpl.hcl"
    destination = "${var.tftp_root}/ipxe/boot.ipxe"
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /srv/tftpboot/pxelinux.cfg",
      <<-EOT
      cat <<EOF >/srv/tftpboot/pxelinux.cfg/default
      ${templatefile("${path.root}/templates/pxelinux.cfg/default.pkrtpl.hcl", {
        k8s_ubuntu_version = var.k8s_ubuntu_version,
        k8s_iso_url        = local.k8s_iso_url,
        pxe_server_ip      = var.pxe_server_ip
      })}
      EOF
      EOT
    ]
  }

  # Install dependencies and PXE binaries
  provisioner "shell" {
    inline = [
      "DEBIAN_FRONTEND=noninteractive apt update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq nginx wget tftp-hpa syslinux-common pxelinux",

      # iPXE for UEFI boot
      "wget -q https://boot.ipxe.org/ipxe.efi -O /srv/tftpboot/ipxe/ipxe.efi",

      "cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftpboot/",
      "cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftpboot/",

      # Download Ubuntu netboot kernel/initrd
      "wget -q https://releases.ubuntu.com/${var.k8s_ubuntu_version}/netboot/amd64/linux -O /var/www/html/pxe/ubuntu/${var.k8s_ubuntu_version}/vmlinuz",
      "wget -q https://releases.ubuntu.com/${var.k8s_ubuntu_version}/netboot/amd64/initrd -O /var/www/html/pxe/ubuntu/${var.k8s_ubuntu_version}/initrd",
      "cp /var/www/html/pxe/ubuntu/${var.k8s_ubuntu_version}/vmlinuz /srv/tftpboot/ubuntu/${var.k8s_ubuntu_version}/vmlinuz",
      "cp /var/www/html/pxe/ubuntu/${var.k8s_ubuntu_version}/initrd /srv/tftpboot/ubuntu/${var.k8s_ubuntu_version}/initrd",

      "chmod -R 755 /var/www/html",
      "chmod -R 755 /srv/tftpboot"
    ]
  }
}
