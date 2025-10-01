build {
  name    = "pxe-server"
  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq syslinux-common pxelinux nfs-kernel-server",
      "mkdir -p /boot/firmware",
    ]
  }
}
