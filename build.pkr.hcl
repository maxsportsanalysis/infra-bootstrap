build {
  name = "pxe-server"

  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      "mkdir -p /boot/firmware",
      "HASH=$(openssl passwd -6 '${var.rpi_password}')",
      "echo \"${var.rpi_username}:$HASH\" | sudo tee /boot/firmware/userconf"
    ]
  }

  provisioner "shell" {
    inline = [
      "BOOT_UUID=$(blkid -s PARTUUID -o value /dev/loop0p1)",
      "ROOT_UUID=$(blkid -s PARTUUID -o value /dev/loop0p2)",
      "sudo sed -i \"s|root=PARTUUID=[^ ]*|root=PARTUUID=$ROOT_UUID|\" /bootfs/cmdline.txt",
      "echo \"PARTUUID=$BOOT_UUID  /boot  vfat  defaults  0  2\" | sudo tee /rootfs/etc/fstab",
      "echo \"PARTUUID=$ROOT_UUID  /      ext4  defaults,noatime  0  1\" | sudo tee -a /rootfs/etc/fstab"
    ]
  }
}