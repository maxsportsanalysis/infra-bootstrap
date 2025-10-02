packer {
  required_version = ">= 1.14.0"

  required_plugins {
    arm-image = {
      version = ">= 0.2.7"
      source  = "github.com/solo-io/arm-image"
    }
  }
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

  # Drop first-run provisioning script
  provisioner "file" {
    source      = "provisioners/firstrun.sh"
    destination = "/boot/firmware/firstrun.sh"
  }

  # Patch cmdline.txt so firstrun.sh executes
  provisioner "shell" {
    environment_vars = [
      "RPI_USERNAME=${env.rpi_username}",
      "RPI_PASSWORD=${env.rpi_password}",
      "RPI_HOSTNAME=${var.rpi_hostname}"
    ]

    inline = [
      "sed -i 's|$| systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target|' /boot/firmware/cmdline.txt"
    ]
  }
}
