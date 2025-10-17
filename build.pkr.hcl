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

variable "k8s_username" {
  type      = string
  description = "Username for Kubernetes"
  sensitive = true
}

variable "k8s_password" {
  type      = string
  description = "Password for Kubernetes"
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
      "mkdir -p /etc/dnsmasq.d /etc/nginx/sites-available /var/www/html/pxe/ubuntu/ /var/www/html/pxe/rescue /srv/tftpboot/ipxe /srv/tftpboot/pxelinux.cfg"
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

  provisioner "file" {
    source      = "configs/pxelinux.cfg/default"
    destination = "/srv/tftpboot/pxelinux.cfg/default"
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
      "mkdir -p /var/www/html/ipxe /var/www/html/pxe/ubuntu/24.04 /srv/tftpboot/ubuntu/24.04 /var/www/html/pxe/rescue",
      
      # Install dependencies
      "DEBIAN_FRONTEND=noninteractive apt update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq nginx wget tftp-hpa syslinux-common pxelinux",

      # Download iPXE for UEFI
      "wget -q https://boot.ipxe.org/ipxe.efi -O /srv/tftpboot/ipxe/ipxe.efi",
      # "wget -q https://boot.ipxe.org/undionly.kpxe -O /srv/tftpboot/ipxe/undionly.kpxe",

      "cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftpboot/",
      "cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftpboot/",
      #"cp /usr/lib/syslinux/modules/bios/menu.c32 /srv/tftp/",
      #"cp /usr/lib/syslinux/modules/bios/vesamenu.c32 /srv/tftp/",

      # Download Ubuntu 24.04 amd64 netboot kernel/initrd
      "wget -q https://releases.ubuntu.com/24.04/netboot/amd64/linux -O /var/www/html/pxe/ubuntu/24.04/vmlinuz",
      "wget -q https://releases.ubuntu.com/24.04/netboot/amd64/initrd -O /var/www/html/pxe/ubuntu/24.04/initrd",

      "cp /var/www/html/pxe/ubuntu/24.04/vmlinuz /srv/tftpboot/ubuntu/24.04/vmlinuz",
      "cp /var/www/html/pxe/ubuntu/24.04/initrd /srv/tftpboot/ubuntu/24.04/initrd",

      "chmod -R 755 /var/www/html",
      "chmod -R 755 /srv/tftpboot"
    ]
  }

  provisioner "shell" {
    inline = [
      # Create the directory for the autoinstall files
      "mkdir -p /var/www/html/autoinstall",

      # Create an empty meta-data file (required for NoCloud)
      "echo 'instance-id: ubuntu-server' > /var/www/html/autoinstall/meta-data",
      "echo 'local-hostname: maxs-sports-analysis-server' >> /var/www/html/autoinstall/meta-data",

      # Write the user-data configuration to the correct path
      <<-EOT
      cat <<'EOF' >/var/www/html/autoinstall/user-data
      #cloud-config
      autoinstall:
        version: 1
        early-commands:
          - ping -c1 8.8.8.8 || true
          - ip link
          - ip addr
          - dhclient -v enp0s25 || true
        locale: en_US.UTF-8
        keyboard:
          layout: us
          variant: ''
        codecs:
          install: false
        drivers:
          install: false
        oem:
          install: auto
        source:
          id: ubuntu-server
          search_drivers: false
        network:
          version: 2
          ethernets:
            all-eth:
              match:
                name: "*"
              dhcp4: true
              optional: true
              nameservers:
                addresses: [8.8.8.8, 1.1.1.1]
        identity:
          hostname: maxs-sports-analysis-server
          password: $${openssl passwd -6 "${var.k8s_password}"}
          realname: Maxim Cilek
          username: mcilek
        ssh:
          allow-pw: true
          authorized-keys: []
          install-server: false
        storage:
          config:
            # Physical Disk
            - type: disk
              id: disk0
              match:
                size: largest
              wipe: superblock
              ptable: gpt
              name: disk0

            # Boot Partition
            - type: partition
              id: boot-partition
              device: disk0
              size: 1G
              flag: boot

            # LVM PV
            - type: partition
              id: lvm-partition
              device: disk0
              size: 900G

            - type: lvm_volgroup
              id: vg0
              name: vg0
              devices: [lvm-partition]

            # Core OS
            - type: lvm_volume
              id: lv_root
              name: root
              volgroup: vg0
              size: 50G

            - type: lvm_volume
              id: lv_var
              name: var
              volgroup: vg0
              size: 40G

            # Container Runtime
            - type: lvm_volume
              id: lv_containerd
              name: containerd
              volgroup: vg0
              size: 120G

            # Kubernetes Storage
            - type: lvm_volume
              id: lv_longhorn
              name: longhorn
              volgroup: vg0
              size: 250G

            # Kafka / Logs
            - type: lvm_volume
              id: lv_kafka
              name: kafka
              volgroup: vg0
              size: 200G

            # Home
            - type: lvm_volume
              id: lv_home
              name: home
              volgroup: vg0
              size: 50G

            # Mount Points
            - type: format
              id: fmt_boot
              fstype: ext4
              volume: boot-partition
              mountpoint: /boot

            - type: format
              id: fmt_root
              fstype: ext4
              volume: lv_root
              mountpoint: /

            - type: format
              id: fmt_var
              fstype: ext4
              volume: lv_var
              mountpoint: /var

            - type: format
              id: fmt_containerd
              fstype: ext4
              volume: lv_containerd
              mountpoint: /var/lib/containerd

            - type: format
              id: fmt_longhorn
              fstype: ext4
              volume: lv_longhorn
              mountpoint: /var/lib/longhorn

            - type: format
              id: fmt_kafka
              fstype: ext4
              volume: lv_kafka
              mountpoint: /var/lib/kafka

            - type: format
              id: fmt_home
              fstype: ext4
              volume: lv_home
              mountpoint: /home

        apt:
          sources:
            kubernetes:
              source: "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main"

        packages:
          - htop
          - vim
          - apt-transport-https
          - ca-certificates
          - curl
          - openssh-server

        late-commands:
          - curtin in-target --target=/target -- swapoff -a || true
          - curtin in-target --target=/target -- sed -i '/ swap / s/^/#/' /etc/fstab || true
          - curtin in-target --target=/target -- bash -c "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"

        error-commands:
          - curtin in-target --target=/target -- bash -c "tar -czf /tmp/install-logs.tgz /var/log/installer || true"
      EOF
      EOT
    ]
  }

}
