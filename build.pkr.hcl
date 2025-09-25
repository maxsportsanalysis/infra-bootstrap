build {
  name = "pxe-server"

  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      "HASH=$(openssl passwd -6 '${var.rpi_password}')",
      "echo '${var.rpi_username}:$HASH' | sudo tee /boot/firmware/userconf"
    ]
  }

  provisioner "shell" {
    inline = [
      "LOOPDEV=$(losetup -j /dev/disk/by-label/rootfs | cut -d: -f1 || true)",
      "[ -z \"$LOOPDEV\" ] && LOOPDEV=$(losetup -a | grep rootfs | cut -d: -f1 || true)",
      "if [ -n \"$LOOPDEV\" ]; then",
      "  PARTUUID=$(blkid -s PARTUUID -o value $LOOPDEV)",
      "  sudo sed -i \"s|root=PARTUUID=[^ ]*|root=PARTUUID=$PARTUUID|\" /boot/firmware/cmdline.txt",
      "fi"
    ]
  }
}