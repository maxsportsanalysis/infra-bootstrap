build {
  name    = "pxe-server"
  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq syslinux-common pxelinux nfs-kernel-server",
      "mkdir -p /srv/tftp/pxelinux.cfg"
    ]
  }
  
  provisioner "file" {
    source      = "configs/dnsmasq.conf"
    destination = "/etc/dnsmasq.conf"
  }

  provisioner "file" {
    source      = "tftpboot/pxelinux.cfg/default"
    destination = "/srv/tftp/pxelinux.cfg/default"
  }

  provisioner "shell" {
    inline = [
      "cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/",
      "cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftp/",
      "systemctl enable dnsmasq",
      "systemctl restart dnsmasq"
    ]
  }
}
