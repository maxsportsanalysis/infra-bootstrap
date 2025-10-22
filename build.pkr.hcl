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
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y git python3 python3-apt python3-pip python3-venv python3-dev redis-server locales",
      
      
      "wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -",
      "sh -c 'echo \"deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main\" > /etc/apt/sources.list.d/pgdg.list'",
      "apt-get update",
      
      "python3 -m venv /opt/ansible-env",
      "/opt/ansible-env/bin/pip install --upgrade pip",
      "/opt/ansible-env/bin/pip install ansible-core==${var.ansible_version}",
      "/opt/ansible-env/bin/pip install psycopg2-binary",
      "ln -s /opt/ansible-env/bin/ansible /usr/local/bin/ansible",
      "ln -s /opt/ansible-env/bin/ansible-playbook /usr/local/bin/ansible-playbook",
      "mkdir -p /root/.ansible/collections",
      "sed -i 's/^# *\\(en_US.UTF-8\\)/\\1/' /etc/locale.gen",
      "locale-gen",
      "update-locale LANG=en_US.UTF-8",
      "if [ ! -f /var/lib/postgresql/$(ls /usr/lib/postgresql)/main/PG_VERSION ]; then pg_createcluster $(ls /usr/lib/postgresql) main --start; fi"
    ]
  }

  provisioner "file" {
    source      = "ansible/collections/requirements.yaml"
    destination = "/root/.ansible/collections/requirements.yaml"
  }

  provisioner "shell" {
    inline = [
      "/opt/ansible-env/bin/ansible-galaxy install -r /root/.ansible/collections/requirements.yaml"
    ]
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /tmp/ansible/vars",
      "ANSIBLE_VAULT_PASSWORD='${var.ansible_vault_password}' /usr/bin/ansible-vault encrypt_string '${var.nautobot_password}' --name 'nautobot_postgres_password' > /tmp/ansible/vars/nautobot-vault.yml"
    ]
  }

  provisioner "shell" {
    inline = ["echo '${var.ansible_vault_password}' > /tmp/ansible/vault-pass.txt"]
  }



  provisioner "ansible-local" {
    playbook_file   = "ansible/playbooks/nautobot-db.yaml"
    command = "/opt/ansible-env/bin/ansible-playbook"
    playbook_dir  = "ansible"
    extra_arguments = [
      "--vault-password-file", "/tmp/ansible/vault-pass.txt"
    ]
  }

  provisioner "shell" {
    inline = ["rm -f /tmp/ansible/vault-pass.txt /tmp/ansible/vars/nautobot-vault.yml"]
  }
}