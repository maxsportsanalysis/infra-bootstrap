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
      "chmod +x /boot/firstrun.sh",
      "sed -i 's|$| systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target|' /boot/cmdline.txt"
    ]
  }
}