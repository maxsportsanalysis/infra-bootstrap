
variable "file_url" {
    type = string
    description = "The URL of the OS image file."
}

variable "file_target_extension" {
  type    = string
  default = "xz"
}

variable "file_checksum" {
    type = string
    description = "The checksum value of `file_checksum_url`."
    default = ""
}

variable "file_checksum_url" {
    type = string
    description = "The checksum file URL of `file_url`."
    default = ""
}

variable "file_checksum_type" {
    type = string
    description = "The checksum type of `file_checksum_url`."
    default = "sha256"
}

variable "ssh_user" {
    type = string
    default = "admin"
}

variable "ssh_pass" {
    type = string
    default = "password"
}