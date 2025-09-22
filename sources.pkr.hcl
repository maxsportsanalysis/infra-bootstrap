source "arm-image" "raspberry_pi_os" {
  iso_urls = [var.iso_url]
  iso_checksum = var.iso_checksum
  iso_target_extension = var.iso_target_extension
  
  output_filename = var.image_path
  disable_embedded = var.disable_embedded

  additional_chroot_mounts = [
    ["bind", "/tmp", "/tmp"]
  ]

  image_mounts = [
    "/boot/firmware",
    "/"
  ]
}