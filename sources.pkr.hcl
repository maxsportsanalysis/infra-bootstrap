source "arm-image" "raspberry_pi_os" {
  iso_url      = "https://downloads.raspberrypi.org/raspios_lite_arm64_latest"
  iso_checksum = "62d025b9bc7ca0e1facfec74ae56ac13978b6745c58177f081d39fbb8041ed45"

  output_directory  = "build/pi-pxe-server"
  qemu_binary  = "/usr/bin/qemu-aarch64-static"
  format       = "raw"
  target_image_size = "8G"


  host            = var.ssh_host
  ssh_username    = var.ssh_user
  ssh_password    = var.ssh_pass
  ssh_timeout     = "15m"
}