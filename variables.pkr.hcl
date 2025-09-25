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

variable "qemu_binary" {
  type    = string
  default = null
}

variable "rpi_username" {
  type = string
}

variable "rpi_password" {
  type = string
  sensitive = true
}