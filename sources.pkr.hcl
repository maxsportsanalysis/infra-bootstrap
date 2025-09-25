source "arm-image" "raspberry_pi_os" {
  iso_urls = [var.iso_url]
  iso_checksum = var.iso_checksum
  
  output_filename = var.image_path

  image_mounts = [
    "/boot/firmware",
    "/"
  ]
}