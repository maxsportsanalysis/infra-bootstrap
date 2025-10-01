build {
  name    = "pxe-server"
  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "mkdir -p /boot/firmware"
    ]
  }
}
