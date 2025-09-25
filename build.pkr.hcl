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
    destination = "/boot/firmware/firstrun.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /boot/firmware/firstrun.sh",
      # Clean out any old systemd.run entries
      "sed -i 's| systemd.run=.*||g' /boot/firmware/cmdline.txt",
      # Append the first-run hook
      "sed -i 's|$| systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target|' /boot/firmware/cmdline.txt"
    ]
  }

}