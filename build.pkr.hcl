build {
  name = "pxe-server"

  sources = ["source.arm-image.raspberry_pi_os"]

  "chroot_mounts": [
    ["proc", "proc", "/proc"],
    ["sysfs", "sysfs", "/sys"],
    ["bind", "/dev", "/dev"],
    ["devpts", "devpts", "/dev/pts"],
    ["binfmt_misc", "binfmt_misc", "/proc/sys/fs/binfmt_misc"],
    ["bind", "/run/resolvconf", "/run/resolvconf"]
  ]


  provisioner "file" {
    source      = "configs/dnsmasq.conf"
    destination = "/etc/dnsmasq.d/dnsmasq.conf"
  }

  provisioner "file" {
    source      = "configs/pxelinux.cfg/default"
    destination = "/srv/tftpboot/pxelinux/pxelinux.cfg/default"
  }
}