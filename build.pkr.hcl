build {
  name = "pxe-server"

  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      "echo 'hello'", 
      "mount"
    ]
  }

  provisioner "shell" {
    inline = ["touch /boot/ssh"]
  }


  provisioner "shell" {
    inline = [
      "mkdir -p /etc/dnsmasq.d",
      "mkdir -p /srv/tftpboot/pxelinux/pxelinux.cfg"
    ]
  }
}