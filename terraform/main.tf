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
  zone      = var.zone-a
}

#===network===

resource "yandex_vpc_network" "network" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = var.zone-a
  v4_cidr_blocks = ["192.168.10.0/24"]
  network_id     = yandex_vpc_network.network.id
}

resource "yandex_vpc_subnet" "subnet-2" {
  name           = "subnet2"
  zone           = var.zone-b
  v4_cidr_blocks = ["192.168.20.0/24"]
  network_id     = yandex_vpc_network.network.id
}


#=====vm======
#====nginx====
resource "yandex_compute_disk" "nginx-bd-1" {
  name     = "nginx-boot-disk-1"
  zone     = var.zone-a
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "nginx-vm-1" {
  name                      = "nginx-1"
  allow_stopping_for_update = true
  zone                      = var.zone-a
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
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
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
  zone     = var.zone-b
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "nginx-vm-2" {
  name                      = "nginx-2"
  allow_stopping_for_update = true
  zone                      = var.zone-b
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
    subnet_id = yandex_vpc_subnet.subnet-2.id
    nat       = true
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
    subnet_id    = yandex_vpc_subnet.subnet-1.id
    ip_address   = yandex_compute_instance.nginx-vm-1.network_interface.0.ip_address
  }

  target {
    subnet_id    = yandex_vpc_subnet.subnet-2.id
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


#===prometheus===
/*resource "yandex_compute_disk" "prometheus-bd" {
  name     = "prometheus-boot-disk"
  zone     = var.zone-a
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "prometheus-vm" {
  name                      = "prometheus"
  allow_stopping_for_update = true
  zone                      = var.zone-a
  platform_id               = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.prometheus-bd.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
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
  zone     = var.zone-a
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "grafana-vm" {
  name                      = "grafana"
  allow_stopping_for_update = true
  zone                      = var.zone-a
  platform_id               = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.grafana-bd.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
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
  zone     = var.zone-a
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "elastic-vm" {
  name                      = "elastic"
  allow_stopping_for_update = true
  zone                      = var.zone-a
  platform_id               = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.elastic-bd.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
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
  zone     = var.zone-a
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "kibana-vm" {
  name                      = "kibana"
  allow_stopping_for_update = true
  zone                      = var.zone-a
  platform_id               = "standard-v3"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.kibana-bd.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
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
  zone     = var.zone-a
  image_id = var.ubuntu-id
  size     = 20
}

resource "yandex_compute_instance" "bastion-vm" {
  name                      = "bastion"
  allow_stopping_for_update = true
  zone                      = var.zone-a
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
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    user-data = "${file("${var.metadata-path}")}"
  }

  scheduling_policy {
    preemptible = var.preemptible
  }
}*/

#===ansible info====
resource "local_file" "ansible_hosts" {
  content  = <<EOT
[nginx]
nginx-1 ansible_host=${yandex_compute_instance.nginx-vm-1.network_interface.0.nat_ip_address}
nginx-2 ansible_host=${yandex_compute_instance.nginx-vm-2.network_interface.0.nat_ip_address}
EOT
  filename = "../ansible/hosts"
}

/*
[prometheus]
${yandex_compute_instance.prometheus-vm.network_interface.0.nat_ip_address}

[grafana]
${yandex_compute_instance.grafana-vm.network_interface.0.nat_ip_address}

[elasticsearch]
${yandex_compute_instance.elastic-vm.network_interface.0.nat_ip_address}

[kibana]
${yandex_compute_instance.kibana-vm.network_interface.0.nat_ip_address}

[bastion-host]
${yandex_compute_instance.bastion-vm.network_interface.0.nat_ip_address}
*/


resource "null_resource" "ansible" {
  provisioner "local-exec" {
    command = "cd ../ansible && ansible-playbook ../ansible/playbook.yaml"
  }

  depends_on = [
    local_file.ansible_hosts
  ]
}