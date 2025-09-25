build {
  name    = "pxe-server"
  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      # Ensure boot directory exists
      "mkdir -p /boot/firmware",

      # Headless SSH + user setup
      "HASH=$(openssl passwd -6 '${var.rpi_password}')",
      "echo \"${var.rpi_username}:$HASH\" | sudo tee /boot/firmware/userconf",
      "touch /boot/firmware/ssh"
    ]
  }

  provisioner "shell" {
    inline = [
      # Get partition UUIDs
      "BOOT_UUID=$(blkid -s PARTUUID -o value /dev/loop0p1)",
      "ROOT_UUID=$(blkid -s PARTUUID -o value /dev/loop0p2)",

      # Patch cmdline.txt to point to the correct root partition
      "sudo sed -i \"s|root=PARTUUID=[^ ]*|root=PARTUUID=$ROOT_UUID|\" /boot/firmware/cmdline.txt",

      # Write fstab inside the chroot (no /rootfs prefix)
      "echo \"PARTUUID=$BOOT_UUID  /boot  vfat  defaults  0  2\" | sudo tee /etc/fstab",
      "echo \"PARTUUID=$ROOT_UUID  /      ext4  defaults,noatime  0  1\" | sudo tee -a /etc/fstab"
    ]
  }
}