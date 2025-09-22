variable "iso_url" {
  type        = string
  description = "URL to the Raspberry Pi OS image."
}

variable "iso_checksum" {
  type        = string
  description = "Checksum of the image, with type prefix (e.g. sha256:)."
}

variable "image_path" {
  type    = string
  default = "rpi-pxe.img"
}

variable "disable_embedded" {
  type    = bool
  default = true
}

variable "target_image_size" {
  type    = number
  default = 3221225472 # 3*1024*1024*1024
}