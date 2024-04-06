terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  token     = var.oauth_token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone_a
}

output "balancer" {
  value = yandex_alb_load_balancer.nginx-balancer.listener.0.endpoint.0.address.0.external_ipv4_address.0.address
}

output "grafana" {
  value = yandex_compute_instance.grafana-vm.network_interface.0.nat_ip_address
}

output "kibana" {
  value = yandex_compute_instance.kibana-vm.network_interface.0.nat_ip_address
}

output "bastion" {
  value = yandex_compute_instance.bastion-vm.network_interface.0.nat_ip_address
}