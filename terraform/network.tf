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