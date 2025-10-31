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

variable "ansible_vault_password" {
  type        = string
  sensitive   = true
}

variable "ansible_version" {
  type        = string
  default     = "2.19.3"
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

variable "nautobot_password" {
  type        = string
  sensitive   = true
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
      "echo \"${var.rpi_username}:$(openssl passwd -6 '${var.rpi_password}')\" > /boot/firmware/userconf.txt",
      "sed -i 's|$| systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target|' /boot/firmware/cmdline.txt",
      "chmod +x /boot/firmware/firstrun.sh"
    ]
  }

  provisioner "shell" {
    inline = [
      # Update system and install Python + venv support
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y curl python3 python3-venv python3-dev",

      # Create virtual environment for Ansible
      "python3 -m venv /opt/ansible-venv",

      # Download the pip bootstrapper
      "curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py",

      # Install pip *inside* the virtual environment using get-pip.py
      "/opt/ansible-venv/bin/python /tmp/get-pip.py",

      # Upgrade pip, setuptools, and wheel inside the venv
      "/opt/ansible-venv/bin/pip install --upgrade pip setuptools wheel",

      # (Optional) Install Ansible and other packages from PyPI
      #"/opt/ansible-venv/bin/pip install ansible-core==${var.ansible_version} psycopg2-binary"
    ]
  }

}