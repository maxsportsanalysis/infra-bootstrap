build {
  name    = "pxe-server"
  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      "mkdir -p /boot/firmware",
    ]
  }

  provisioner "file" {
    source      = "provisioners/firstrun.sh"
    destination = "/boot/firstrun.sh"
  }

  provisioner "shell" {
    inline = [
      # Copy firstrun.sh
      "chmod +x /boot/firstrun.sh",
      # Patch cmdline.txt so Pi runs it on first boot
      "sudo sed -i 's|$| systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target|' /boot/cmdline.txt"
    ]
  }
}