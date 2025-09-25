build {
  name = "pxe-server"

  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      "mkdir -p /boot/firmware",
      "touch /boot/ssh",
    ]
  }

  provisioner "shell" {
    inline = [
      "ROOT_DEV=$(blkid -t TYPE=ext4 -o device | head -n1)",
      "ROOT_UUID=$(blkid -s PARTUUID -o value $ROOT_DEV)",
      "sudo sed -i \"s|root=PARTUUID=[^ ]*|root=PARTUUID=$ROOT_UUID|\" /boot/firmware/cmdline.txt"
    ]
  }
}