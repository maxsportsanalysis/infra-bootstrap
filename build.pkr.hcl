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
      "DEBIAN_FRONTEND=noninteractive apt-get install -y git python3 python3-apt python3-pip python3-venv python3-dev postgresql",
      "python3 -m venv /opt/ansible-env",
      "/opt/ansible-env/bin/pip install --upgrade pip",
      "/opt/ansible-env/bin/pip install ansible-core==${var.ansible_version}",
      "ln -s /opt/ansible-env/bin/ansible /usr/local/bin/ansible",
      "ln -s /opt/ansible-env/bin/ansible-playbook /usr/local/bin/ansible-playbook"
    ]
  }

  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y lsb-release curl gpg",
      "curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg",
      "chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg",
      "echo 'deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main' | tee /etc/apt/sources.list.d/redis.list",
      "apt-get update",
      "apt-get install -y redis-server"
    ]
  }

  provisioner "ansible" {
    playbook_file   = "playbooks/nautobot-db.yaml"
    extra_arguments = [
      "--extra-vars", "nautobot_db_password=${var.rpi_password} ansible_python_interpreter=/usr/bin/python3"
    ]
  }
}
