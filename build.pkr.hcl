build {
  name    = "pxe-server"
  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq syslinux-common pxelinux nfs-kernel-server",
      "mkdir -p /srv/tftp/pxelinux.cfg",
      "mkdir -p /boot/firmware",
      "mkdir -p /etc",
      "sed -i 's|$| systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target|' /boot/cmdline.txt"
    ]
  }

  provisioner "file" {
    source      = "provisioners/firstrun.sh"
    destination = "/boot/firstrun.sh"
  }
  
  provisioner "file" {
    source      = "configs/dnsmasq.conf"
    destination = "/etc/dnsmasq.conf"
  }

  provisioner "file" {
    source      = "tftpboot/pxelinux.cfg/default"
    destination = "/srv/tftp/pxelinux.cfg/default"
  }
}
