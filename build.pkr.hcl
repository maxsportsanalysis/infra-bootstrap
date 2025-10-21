packer {
  required_version = ">= 1.14.0"

  required_plugins {
    arm-image = {
      version = ">= 0.2.7"
      source  = "github.com/solo-io/arm-image"
    }
  }
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

variable "python_version" {
  type    = string
  default = "3.12"
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
      "apt-get update",

      # Install build dependencies for Python
      "DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential wget curl libssl-dev zlib1g-dev libncurses5-dev libncursesw5-dev libreadline-dev libsqlite3-dev libgdbm-dev libdb5.3-dev libbz2-dev libexpat1-dev liblzma-dev tk-dev libffi-dev uuid-dev",

      # Download Python 3.12 source
      "cd /usr/src && wget https://www.python.org/ftp/python/3.12.12/Python-3.12.12.tgz",
      "cd /usr/src && tar xvf Python-3.12.12.tgz",

      # Build and install Python 3.12 into /opt/python3.12 (isolated, non-default)
      "cd /usr/src/Python-3.12.12 && ./configure --prefix=/opt/python3.12 --enable-optimizations",
      "cd /usr/src/Python-3.12.12 && make -j$(nproc)",
      "cd /usr/src/Python-3.12.12 && make altinstall",

      # Create virtual environment for Ansible
      "/opt/python3.12/bin/python3.12 -m venv /opt/ansible-env",

      # Upgrade pip, setuptools, wheel inside venv
      "/opt/ansible-env/bin/pip install --upgrade pip setuptools wheel",

      # Install Ansible core
      "/opt/ansible-env/bin/pip install ansible-core==${var.ansible_version}",

      # Optional convenience symlinks (do NOT override system Python)
      "ln -sf /opt/ansible-env/bin/ansible /usr/local/bin/ansible",
      "ln -sf /opt/ansible-env/bin/ansible-playbook /usr/local/bin/ansible-playbook"
    ]
  }

}
