variable "zone_a" {
  type    = string
  default = "ru-central1-a"
}

variable "zone_b" {
  type    = string
  default = "ru-central1-b"
}

variable "zone_d" {
  type    = string
  default = "ru-central1-d"
}

variable "preemptible" {
  type    = bool
  default = true
}

variable "nat_for_private" {
  type    = bool
  default = false
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

variable "nginx_1_ip" {
  type    = string
  default = "192.168.10.10"
}

variable "nginx_2_ip" {
  type    = string
  default = "192.168.20.10"
}

variable "prometheus_ip" {
  type    = string
  default = "192.168.10.11"
}

variable "elasticsearch_ip" {
  type    = string
  default = "192.168.10.12"
}

variable "grafana_ip" {
  type    = string
  default = "192.168.30.10"
}

variable "kibana_ip" {
  type    = string
  default = "192.168.30.11"
}

variable "bastion_ip" {
  type    = string
  default = "192.168.30.12"
}
