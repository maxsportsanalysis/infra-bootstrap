build {
  name    = "pxe-server"
  sources = ["source.arm-image.raspberry_pi_os"]

  # Copy the script into the boot partition (FAT32)
  provisioner "file" {
    source      = "provisioners/firstrun.sh"
    destination = "/boot/firstrun.sh"
  }

  # Make it executable and patch cmdline.txt
  provisioner "shell" {
    inline = [
      "chmod +x /boot/firstrun.sh",

      # Remove any old systemd.run entries
      "sed -i 's| systemd.run=.*||g' /boot/cmdline.txt",

      # Remove any init=... (firstboot) so systemd is PID 1
      "sed -i 's| init=[^ ]*||g' /boot/cmdline.txt",

      # Append systemd.run to call your firstrun script
      "sed -i 's|$| systemd.run=/boot/firstrun.sh systemd.unit=kernel-command-line.target|' /boot/cmdline.txt"
    ]
  }
}
