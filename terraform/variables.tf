variable "zone-a" {
  type    = string
  default = "ru-central1-a"
}

variable "zone-b" {
  type    = string
  default = "ru-central1-b"
}

variable "preemptible" {
  type    = bool
  default = true
}

variable "metadata-path" {
  type    = string
  default = "./meta.yml"
}

variable "ubuntu-id" {
  type    = string
  default = "fd8ba9d5mfvlncknt2kd"
}

variable "oauth_token" {
  type = string
}

variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

