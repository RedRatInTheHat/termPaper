#===snapshot schedule====
resource "yandex_compute_snapshot_schedule" "default" {
  name           = "all-disks-snapshots"

  schedule_policy {
	  expression = "0 0 * * *"
  }

  snapshot_count = 7

  disk_ids = [yandex_compute_disk.nginx-bd-1.id, yandex_compute_disk.nginx-bd-2.id, yandex_compute_disk.prometheus-bd.id, 
  yandex_compute_disk.grafana-bd.id, yandex_compute_disk.elastic-bd.id, yandex_compute_disk.kibana-bd.id, 
  yandex_compute_disk.bastion-bd.id]
}

#======single snapshot=======
resource "yandex_compute_snapshot" "nginx-snapshot-1" {
  name           = "nginx-snapshot-1"
  source_disk_id = yandex_compute_disk.nginx-bd-1.id

  depends_on     = [ null_resource.ansible ]
}

resource "yandex_compute_snapshot" "nginx-snapshot-2" {
  name           = "nginx-snapshot-2"
  source_disk_id = yandex_compute_disk.nginx-bd-2.id

  depends_on     = [ null_resource.ansible ]
}

resource "yandex_compute_snapshot" "prometheus-snapshot" {
  name           = "prometheus-snapshot"
  source_disk_id = yandex_compute_disk.prometheus-bd.id

  depends_on     = [ null_resource.ansible ]
}

resource "yandex_compute_snapshot" "grafana-snapshot" {
  name           = "grafana-snapshot"
  source_disk_id = yandex_compute_disk.grafana-bd.id

  depends_on     = [ null_resource.ansible ]
}

resource "yandex_compute_snapshot" "elastic-snapshot" {
  name           = "elastic-snapshot"
  source_disk_id = yandex_compute_disk.elastic-bd.id

  depends_on     = [ null_resource.ansible ]
}

resource "yandex_compute_snapshot" "kibana-snapshot" {
  name           = "kibana-snapshot"
  source_disk_id = yandex_compute_disk.kibana-bd.id

  depends_on     = [ null_resource.ansible ]
}

resource "yandex_compute_snapshot" "bastion-snapshot" {
  name           = "bastion-snapshot"
  source_disk_id = yandex_compute_disk.bastion-bd.id

  depends_on     = [ null_resource.ansible ]
}