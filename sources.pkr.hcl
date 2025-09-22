source "arm-image" "raspberry_pi_os" {
  iso_urls = [var.iso_url]
  iso_checksum = var.iso_checksum
  
  output_filename = var.image_path
  disable_embedded = var.disable_embedded
  target_image_size = var.target_image_size
}