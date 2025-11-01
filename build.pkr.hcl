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
      "apt-get update",

      "DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential pkg-config wget",

      # --- Recommended Dependencies ---
      # Default (Required):
      #   libffi-dev                                 -> ctypes (FFI bindings)
      #   libmpdec-dev                               -> decimal (accurate financial math)
      #   libssl-dev                                 -> HTTPS/TLS (ssl, hashlib)
      # Optional:
      #   libsqlite3-dev                             -> sqlite3 (lightweight DB)
      #   uuid-dev                                   -> uuid (identifiers, config mgmt)
      # Excluded (Dev-only / Obsolete):
      #   gdb, lcov                                  -> Debugger, Code Coverage (dev/test only)
      #   libgdbm-dev, libgdbm-compat-dev            -> Legacy DB (rarely used)
      #   libncurses-dev, libreadline-dev, tk-dev    -> Terminal UI, Interactive Input, Tkinter (dev/test only)
      #   inetutils-inetd                            -> On-Demand Service Startup (obsolete use systemd)

      "DEBIAN_FRONTEND=noninteractive apt-get install -y libffi-dev libssl-dev libsqlite3-dev uuid-dev",


      # --- Compression Libraries ---
      # Default (Required):
      #   zlib1g-dev                                 -> zlib/gzip (essential, fast)
      #   libzstd-dev                                -> zstd (modern, best speed/ratio tradeoff)
      # Optional:
      #   libbz2-dev                                 -> bzip2 (slow, legacy)
      #   liblzma-dev                                -> xz/lzma (high compression, heavy CPU/RAM)
      
      "DEBIAN_FRONTEND=noninteractive apt-get install -y zlib1g-dev libzstd-dev",
      

      # Build Python Version From Source      
      "wget --progress=dot:mega -P /tmp https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tgz",
      "tar -xf /tmp/Python-3.12.0.tgz -C /tmp",
      "/tmp/Python-3.12.0/configure --prefix=/usr/local",
      #"/tmp/Python-3.12.0/configure --enable-optimizations --with-lto --prefix=/usr/local",
      "make -j$(nproc)",
      "make altinstall",

      # Cleanup
      "apt-get clean",
      "rm -rf /tmp/Python-3.12.0 /tmp/Python-3.12.0.tgz" # /var/lib/apt/lists/*
    ]
  }
}