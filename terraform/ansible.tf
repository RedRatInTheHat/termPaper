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