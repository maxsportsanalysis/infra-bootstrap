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
      # Clean out any old systemd.run entries
      "sed -i 's| systemd.run=.*||g' /boot/cmdline.txt",
      # Append the first-run hook
      "sed -i 's|$| systemd.run=/boot/firstrun.sh systemd.unit=kernel-command-line.target|' /boot/cmdline.txt"
    ]
  }

}