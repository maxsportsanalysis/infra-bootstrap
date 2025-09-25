build {
  name = "pxe-server"

  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      "HASH=$(openssl passwd -6 '${var.rpi_password}')",
      "echo '${var.rpi_username}:$HASH' | sudo tee /boot/firmware/userconf"
    ]
  }
}