build {
  name = "pxe-server"

  sources = ["source.arm-image.raspberry_pi_os"]


  provisioner "file" {
    source      = "configs/dnsmasq.conf"
    destination = "/etc/dnsmasq.d/dnsmasq.conf"
  }

  provisioner "file" {
    source      = "configs/pxelinux.cfg/default"
    destination = "/srv/tftpboot/pxelinux/pxelinux.cfg/default"
  }
}