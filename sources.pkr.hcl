source "arm-image" "raspberry_pi_os" {
  file_urls      = [var.file_url]
  file_target_extension = "img.xz"

  file_checksum         = var.file_checksum
  file_checksum_url     = var.file_checksum_url
  file_checksum_type    = var.file_checksum_type

  image_build_method    = "reuse"
  image_path = var.image_path

  ssh_username    = var.ssh_user
  ssh_password    = var.ssh_pass
  ssh_timeout     = "10m"
}