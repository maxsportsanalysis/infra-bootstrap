build {
  name    = "pxe-server"
  sources = ["source.arm-image.raspberry_pi_os"]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "mkdir -p /boot/firmware"
    ]
  }

  provisioner "file" {
    source      = "provisioners/firstrun.sh"
    destination = "/boot/firstrun.sh"
  }

  provisioner "shell" {
    inline = [
      # Add firstboot init if it's not already in cmdline.txt
      "grep -q 'init=/usr/lib/raspberrypi-sys-mods/firstboot' /boot/firmware/cmdline.txt || sed -i 's|rootwait|rootwait quiet init=/usr/lib/raspberrypi-sys-mods/firstboot|' /boot/firmware/cmdline.txt"
    ]
  }

  provisioner "shell" {
    inline = [
      "DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq syslinux-common pxelinux"
    ]
  }
}
