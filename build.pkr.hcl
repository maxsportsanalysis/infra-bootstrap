packer {
  required_version = ">= 1.14.0"

  required_plugins {
    arm-image = {
      version = ">= 0.2.7"
      source  = "github.com/solo-io/arm-image"
    }
    ansible = {
      version = ">= 1.1.4"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "ansible_venv_path" {
  type        = string
  default   = "/opt/ansible-venv"
}

variable "chroot_mounts" {
  type        = list(list(string))
  default     = []
  description = "Host directories to mount into the chroot."
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

variable "qemu_binary" {
  type        = string
  default     = "qemu-arm-static"
  description = "Qemu binary to use."
}

variable "linux_password" {
  type        = string
  sensitive   = true
}

variable "linux_username" {
  type        = string
  sensitive   = true
}

source "arm-image" "raspberry_pi_os" {
  iso_urls        = [var.iso_url]
  iso_checksum    = var.iso_checksum
  output_filename = var.image_path
  qemu_binary     = var.qemu_binary
  image_mounts    = var.image_mounts
  chroot_mounts   = var.chroot_mounts
  target_image_size      = 4294967296
}

build {
  name    = "pxe-server-arm64-prod"
  sources = ["source.arm-image.raspberry_pi_os"]

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
      "echo \"${var.linux_username}:$(openssl passwd -6 '${var.linux_password}')\" > /boot/firmware/userconf.txt",
      "sed -i 's|$| systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target|' /boot/firmware/cmdline.txt",
      "chmod +x /boot/firmware/firstrun.sh"
    ]
  }

  provisioner "file" {
    source      = "requirements.txt"
    destination = "/tmp/requirements.txt"
  }

  provisioner "shell" {
    inline = [
      "apt-get update",
      
      # Virtual Environment Setup
      "python3 -m venv ${var.ansible_venv_path}",
      "chown -R ${var.linux_username}:${var.linux_username} ${var.ansible_venv_path}",
      "chmod -R 750 ${var.ansible_venv_path}",
      
      # Pip Configuration & Ansible Installation
      "${var.ansible_venv_path}/bin/pip config --global unset global.extra-index-url",
      "${var.ansible_venv_path}/bin/pip install --upgrade pip",
      "${var.ansible_venv_path}/bin/pip install -r /tmp/requirements.txt"
      
      "echo 'export PATH=${var.ansible_venv_path}/bin:$PATH' >> /home/${var.linux_username}/.bashrc",
      "chown -R ${var.linux_username}:${var.linux_username} /home/${var.linux_username}/.bashrc"
    ]
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /root/.ansible/collections"
    ]
  }

  provisioner "file" {
    source      = "ansible/collections/requirements.yaml"
    destination = "/root/.ansible/collections/requirements.yaml"
  }

  provisioner "shell" {
    inline = [
      "${var.ansible_venv_path}/bin/ansible-galaxy install -r /root/.ansible/collections/requirements.yaml"
    ]
  }
}