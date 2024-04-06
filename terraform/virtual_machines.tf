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
    subnet_id           = yandex_vpc_subnet.private-subnet-1.id
    ip_address          = "${var.nginx_1_ip}"
    nat                 = var.nat_for_private
    security_group_ids  = [ yandex_vpc_security_group.ssh-sg.id, yandex_vpc_security_group.web-sg.id ]
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
    subnet_id           = yandex_vpc_subnet.private-subnet-2.id
    ip_address          = "${var.nginx_2_ip}"
    nat                 = var.nat_for_private
    security_group_ids  = [ yandex_vpc_security_group.ssh-sg.id, yandex_vpc_security_group.web-sg.id ]
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
    ip_address   = "${var.nginx_1_ip}"
  }

  target {
    subnet_id    = yandex_vpc_subnet.private-subnet-2.id
    ip_address   = "${var.nginx_2_ip}"
  }

  depends_on = [
    yandex_compute_instance.nginx-vm-1, yandex_compute_instance.nginx-vm-2
  ]
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
    subnet_id           = yandex_vpc_subnet.private-subnet-1.id
    ip_address          = "${var.prometheus_ip}"
    nat                 = var.nat_for_private
    security_group_ids  = [ yandex_vpc_security_group.ssh-sg.id, yandex_vpc_security_group.prometheus-sg.id ]
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
    subnet_id           = yandex_vpc_subnet.public-subnet-1.id
    ip_address          = "${var.grafana_ip}"
    nat                 = true
    security_group_ids  = [ yandex_vpc_security_group.ssh-sg.id, yandex_vpc_security_group.grafana-sg.id ]
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
    subnet_id           = yandex_vpc_subnet.private-subnet-1.id
    ip_address          = "${var.elasticsearch_ip}"
    nat                 = var.nat_for_private
    security_group_ids  = [ yandex_vpc_security_group.ssh-sg.id, yandex_vpc_security_group.elasticsearch-sg.id ]
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
    subnet_id           = yandex_vpc_subnet.public-subnet-1.id
    ip_address          = "${var.kibana_ip}"
    nat                 = true
    security_group_ids  = [ yandex_vpc_security_group.ssh-sg.id, yandex_vpc_security_group.kibana-sg.id ]
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
    subnet_id           = yandex_vpc_subnet.public-subnet-1.id
    ip_address          = "${var.bastion_ip}"
    nat                 = true
    security_group_ids  = [ yandex_vpc_security_group.bastion-sg.id ]
  }

  metadata = {
    user-data = "${file("${var.metadata-path}")}"
  }

  scheduling_policy {
    preemptible = var.preemptible
  }
}