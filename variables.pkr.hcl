variable "iso_url" {
  type = string
  default = null
  description = "URL to the OS image."
}

variable "iso_checksum" {
  type = string
  default = null
  description = "Checksum of the image, with type prefix (e.g. sha256:)."
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
  default = null
  description = "Where to mounts the image partitions in the chroot. first entry is the mount point of the first partition. etc.."
}

variable "chroot_mounts" {
  type    = list(string)
  default = null
  description = "What directories mount from the host to the chroot. leave it empty for reasonable defaults. array of triplets: [type, device, mntpoint]."
}

variable "rpi_hostname" {
  type    = string
  default = null
}

variable "rpi_username" {
  type    = string
  default = null
}

variable "rpi_password" {
  type    = string
  default = null
}