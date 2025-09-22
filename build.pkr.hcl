build {
  name = "pxe-server"

  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      "mkdir -p /boot",
      "mkdir -p /etc/dnsmasq.d",
      "mkdir -p /srv/tftpboot/pxelinux/pxelinux.cfg"
    ]
  }
}