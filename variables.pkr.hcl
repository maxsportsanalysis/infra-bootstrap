# variables.pkr.hcl

variable "iso_url" {
  type = string
  description = "URL to the OS image."
  default = null
}

variable "iso_checksum" {
  type = string
  description = "Checksum of the image, with type prefix (e.g. sha256:)."
  default = null
}

variable "image_path" {
  type = string
  default = null
}

variable "qemu_binary" {
  type = string
  default = "qemu-arm-static"
  description = "Qemu binary to use. If this is an absolute path, it will be used. Otherwise, we will look for one in your PATH and finally, try to auto fetch one from https://github.com/multiarch/qemu-user-static/"
}

variable "image_mounts" {
  type    = list(string)
  description = "Where to mounts the image partitions in the chroot. first entry is the mount point of the first partition. etc.."
  default = []
}

variable "chroot_mounts" {
  type    = list(list(string))
  description = "What directories mount from the host to the chroot. leave it empty for reasonable defaults. array of triplets: [type, device, mntpoint]."
  default = []
}

variable "rpi_hostname" {
  type        = string
  description = "Default hostname for Raspberry Pi"
  default     = "pxe-bootstrap"
}

variable "rpi_username" {
  type        = string
  description = "Username for Raspberry Pi"
  sensitive   = true
  default = null
}

variable "rpi_password" {
  type        = string
  description = "Password for Raspberry Pi"
  sensitive   = true
  default = null
}