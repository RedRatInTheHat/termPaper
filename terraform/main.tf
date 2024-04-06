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

#===network===
resource "yandex_vpc_network" "network" {
  name = "network1"
}

#====nat=====
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "nat"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt" {
  name       = "route-table"
  network_id = yandex_vpc_network.network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

#=====subnet====
resource "yandex_vpc_subnet" "private-subnet-1" {
  name           = "private-subnet1"
  zone           = var.zone_a
  v4_cidr_blocks = ["192.168.10.0/24"]
  network_id     = yandex_vpc_network.network.id
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_subnet" "private-subnet-2" {
  name           = "private-subnet2"
  zone           = var.zone_b
  v4_cidr_blocks = ["192.168.20.0/24"]
  network_id     = yandex_vpc_network.network.id
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_subnet" "public-subnet-1" {
  name           = "public-subnet1"
  zone           = var.zone_d
  v4_cidr_blocks = ["192.168.30.0/24"]
  network_id     = yandex_vpc_network.network.id
}

#===security groups====
resource "yandex_vpc_security_group" "bastion-sg" {
  name        = "Bastion security group"
  description = "Input SSH connection only"
  network_id  = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "ssh-sg" {
  name        = "SSH security group"
  description = "SSH port is available only for bastion; output isn't restricted"
  network_id  = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["${var.bastion_ip}/32"]
    port           = 22
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "web-sg" {
  name        = "Nginx servers security group"
  description = "Add access for balancer and access to 80 port and exporters"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow HTTP protocol from anywhere"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow HTTPs protocol from anywhere"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow health checks from NLB"
    protocol = "TCP"
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    protocol       = "TCP"
    description    = "Give access to prometheus for nginx-exporter"
    v4_cidr_blocks = ["${var.prometheus_ip}/32"]
    port           = 4040
  }

  ingress {
    protocol       = "TCP"
    description    = "Give access to prometheus for node-exporter"
    v4_cidr_blocks = ["${var.prometheus_ip}/32"]
    port           = 9100
  }
}

resource "yandex_vpc_security_group" "prometheus-sg" {
  name        = "Prometheus security group"
  description = "Add access to prometheus only for grafana"
  network_id  = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    description    = "Give access to prometheus for grafana"
    v4_cidr_blocks = ["${var.grafana_ip}/32"]
    port           = 9090
  }
}

resource "yandex_vpc_security_group" "grafana-sg" {
  name        = "Grafana security group"
  description = "Add access to grafana interface"
  network_id  = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    description    = "Give access to grafana"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 3000
  }
}

resource "yandex_vpc_security_group" "elasticsearch-sg" {
  name        = "Elasticsearch security group"
  description = "Add access to elasticsearch only for kibana and filebeat"
  network_id  = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    description    = "Give access to elasticsearch for kibana and filebeat"
    v4_cidr_blocks = ["${var.kibana_ip}/32", "${var.nginx_1_ip}/32", "${var.nginx_2_ip}/32"]
    port           = 9200
  }
}

resource "yandex_vpc_security_group" "kibana-sg" {
  name        = "Kibana security group"
  description = "Add access to kibana interface"
  network_id  = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    description    = "Give access to kibana"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }
}

#=====vm======
#====nginx====
resource "yandex_compute_disk" "nginx-bd-1" {
  name     = "nginx-boot-disk-1"
  zone     = var.zone_a
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "nginx-vm-1" {
  name                      = "nginx-1"
  allow_stopping_for_update = true
  zone                      = var.zone_a
  platform_id               = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.nginx-bd-1.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private-subnet-1.id
    ip_address = "${var.nginx_1_ip}"
    nat       = var.nat_for_private
    security_group_ids = [ yandex_vpc_security_group.ssh-sg.id, yandex_vpc_security_group.web-sg.id ]
  }

  metadata = {
    user-data = "${file("${var.metadata-path}")}"
  }

  scheduling_policy {
    preemptible = var.preemptible
  }
}

resource "yandex_compute_disk" "nginx-bd-2" {
  name     = "nginx-boot-disk-2"
  zone     = var.zone_b
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "nginx-vm-2" {
  name                      = "nginx-2"
  allow_stopping_for_update = true
  zone                      = var.zone_b
  platform_id               = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.nginx-bd-2.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private-subnet-2.id
    ip_address = "${var.nginx_2_ip}"
    nat       = var.nat_for_private
    security_group_ids = [ yandex_vpc_security_group.ssh-sg.id, yandex_vpc_security_group.web-sg.id ]
  }

  metadata = {
    user-data = "${file("${var.metadata-path}")}"
  }

  scheduling_policy {
    preemptible = var.preemptible
  }
}

#===web servers balancer===

resource "yandex_alb_target_group" "nginx-tg" {
  name           = "nginx-target-group"

  target {
    subnet_id    = yandex_vpc_subnet.private-subnet-1.id
    ip_address   = yandex_compute_instance.nginx-vm-1.network_interface.0.ip_address
  }

  target {
    subnet_id    = yandex_vpc_subnet.private-subnet-2.id
    ip_address   = yandex_compute_instance.nginx-vm-2.network_interface.0.ip_address
  }
}

resource "yandex_alb_backend_group" "nginx-bg" {
  name                     = "nginx-backend-group"

  http_backend {
    name                   = "nginx-backend"
    weight                 = 1
    port                   = 80
    target_group_ids       = [yandex_alb_target_group.nginx-tg.id]
    load_balancing_config {
      panic_threshold      = 90
    }    
    healthcheck {
      timeout              = "10s"
      interval             = "2s"
      healthy_threshold    = 10
      unhealthy_threshold  = 15 
      http_healthcheck {
        path               = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "nginx-router" {
  name          = "nginx-http-router"
}

resource "yandex_alb_virtual_host" "nginx-vh" {
  name                    = "nginx-virtual-host"
  http_router_id          = yandex_alb_http_router.nginx-router.id
  route {
    name                  = "nginx-route"
    http_route {
      http_route_action {
        backend_group_id  = yandex_alb_backend_group.nginx-bg.id
        timeout           = "60s"
      }
    }
  }
}

resource "yandex_alb_load_balancer" "nginx-balancer" {
  name        = "nginx-balancer"
  network_id  = yandex_vpc_network.network.id

  allocation_policy {
    location {
      zone_id   = var.zone_d
      subnet_id = yandex_vpc_subnet.public-subnet-1.id 
    }
  }

  listener {
    name = "nginx-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [ 80 ]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.nginx-router.id
      }
    }
  }
}


#===prometheus===
resource "yandex_compute_disk" "prometheus-bd" {
  name     = "prometheus-boot-disk"
  zone     = var.zone_a
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "prometheus-vm" {
  name                      = "prometheus"
  allow_stopping_for_update = true
  zone                      = var.zone_a
  platform_id               = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.prometheus-bd.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private-subnet-1.id
    ip_address = "${var.prometheus_ip}"
    nat       = var.nat_for_private
    security_group_ids = [ yandex_vpc_security_group.ssh-sg.id, yandex_vpc_security_group.prometheus-sg.id ]
  }

  metadata = {
    user-data = "${file("${var.metadata-path}")}"
  }

  scheduling_policy {
    preemptible = var.preemptible
  }
}

#===grafana===
resource "yandex_compute_disk" "grafana-bd" {
  name     = "grafana-boot-disk"
  zone     = var.zone_d
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "grafana-vm" {
  name                      = "grafana"
  allow_stopping_for_update = true
  zone                      = var.zone_d
  platform_id               = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.grafana-bd.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public-subnet-1.id
    ip_address = "${var.grafana_ip}"
    nat       = true
    security_group_ids = [ yandex_vpc_security_group.ssh-sg.id, yandex_vpc_security_group.grafana-sg.id ]
  }

  metadata = {
    user-data = "${file("${var.metadata-path}")}"
  }

  scheduling_policy {
    preemptible = var.preemptible
  }
}

#===elasticsearch===
resource "yandex_compute_disk" "elastic-bd" {
  name     = "elastic-boot-disk"
  zone     = var.zone_a
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "elastic-vm" {
  name                      = "elastic"
  allow_stopping_for_update = true
  zone                      = var.zone_a
  platform_id               = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 8
  }

  boot_disk {
    disk_id = yandex_compute_disk.elastic-bd.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private-subnet-1.id
    ip_address = "${var.elasticsearch_ip}"
    nat       = var.nat_for_private
    security_group_ids = [ yandex_vpc_security_group.ssh-sg.id, yandex_vpc_security_group.elasticsearch-sg.id ]
  }

  metadata = {
    user-data = "${file("${var.metadata-path}")}"
  }

  scheduling_policy {
    preemptible = var.preemptible
  }
}

#===kibana===
resource "yandex_compute_disk" "kibana-bd" {
  name     = "kibana-boot-disk"
  zone     = var.zone_d
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "kibana-vm" {
  name                      = "kibana"
  allow_stopping_for_update = true
  zone                      = var.zone_d
  platform_id               = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 8
  }

  boot_disk {
    disk_id = yandex_compute_disk.kibana-bd.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public-subnet-1.id
    ip_address = "${var.kibana_ip}"
    nat       = true
    security_group_ids = [ yandex_vpc_security_group.ssh-sg.id, yandex_vpc_security_group.kibana-sg.id ]
  }

  metadata = {
    user-data = "${file("${var.metadata-path}")}"
  }

  scheduling_policy {
    preemptible = var.preemptible
  }
}

#===bastion host===
resource "yandex_compute_disk" "bastion-bd" {
  name     = "bastion-boot-disk"
  zone     = var.zone_d
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "bastion-vm" {
  name                      = "bastion"
  allow_stopping_for_update = true
  zone                      = var.zone_d
  platform_id               = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.bastion-bd.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public-subnet-1.id
    ip_address = "${var.bastion_ip}"
    nat       = true
    security_group_ids = [ yandex_vpc_security_group.bastion-sg.id ]
  }

  metadata = {
    user-data = "${file("${var.metadata-path}")}"
  }

  scheduling_policy {
    preemptible = var.preemptible
  }
}

#===ansible info====
resource "local_file" "ansible_hosts" {
  content  = <<EOT
[bastion-host]
${yandex_compute_instance.bastion-vm.network_interface.0.nat_ip_address}

[nginx]
nginx-1 ansible_host=${ var.nginx_1_ip }
nginx-2 ansible_host=${ var.nginx_2_ip }

[prometheus]
${ var.prometheus_ip }

[grafana]
${ var.grafana_ip }

[elasticsearch]
${ var.elasticsearch_ip }

[kibana]
${ var.kibana_ip }

[bastioners:children]
nginx
prometheus
grafana
elasticsearch
kibana

[bastioners:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q ansibler@${ yandex_compute_instance.bastion-vm.network_interface.0.nat_ip_address } -i ../.ssh/terraform"'

EOT
  filename = "../ansible/hosts"
}

resource "local_file" "tf_variables" {
  content  = <<EOT
nginx_1_ip: "${ var.nginx_1_ip }"
nginx_2_ip: "${ var.nginx_2_ip }"
prometheus_ip: "${ var.prometheus_ip }"
grafana_ip: "${ var.grafana_ip }"
elasticsearch_ip: "${ var.elasticsearch_ip }"
kibana_ip: "${ var.kibana_ip }"
bastion_ip: "${ var.bastion_ip}"
EOT
  filename = "../ansible/group_vars/all/tf_variables.yml"
}


resource "null_resource" "ansible" {
  provisioner "local-exec" {
    command = "cd ../ansible && ansible-playbook playbook.yaml"
  }

  depends_on = [
    local_file.ansible_hosts
  ]
}

# output "nginx_1" {
#   value = yandex_compute_instance.nginx-vm-1.network_interface.0.nat_ip_address
# }

# output "nginx_2" {
#   value = yandex_compute_instance.nginx-vm-2.network_interface.0.nat_ip_address
# }

output "balancer" {
  value = yandex_alb_load_balancer.nginx-balancer.listener.0.endpoint.0.address.0.external_ipv4_address.0.address
}

# output "prometheus" {
#   value = yandex_compute_instance.prometheus-vm.network_interface.0.nat_ip_address
# }

output "grafana" {
  value = yandex_compute_instance.grafana-vm.network_interface.0.nat_ip_address
}

# output "elasticsearch" {
#   value = yandex_compute_instance.elastic-vm.network_interface.0.nat_ip_address
# }

output "kibana" {
  value = yandex_compute_instance.kibana-vm.network_interface.0.nat_ip_address
}

output "bastion" {
  value = yandex_compute_instance.bastion-vm.network_interface.0.nat_ip_address
}