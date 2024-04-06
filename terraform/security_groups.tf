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
    description       = "Allow health checks from NLB"
    protocol          = "TCP"
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