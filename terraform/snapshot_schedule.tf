resource "yandex_compute_snapshot_schedule" "daily" {
  name        = "diploma-daily-snapshots"
  description = "Ежедневные снимки инфраструктуры"

  schedule_policy {
    expression = "0 3 ? * *"
  }

  retention_period = "168h0m0s"

  snapshot_spec {
    description = "Ежедневный автоматический снимок"

    labels = {
      project = "diploma"
      backup  = "daily"
    }
  }

  disk_ids = [
    yandex_compute_instance.admin_bastion.boot_disk[0].disk_id,
    yandex_compute_instance.web_1.boot_disk[0].disk_id,
    yandex_compute_instance.web_2.boot_disk[0].disk_id,
    yandex_compute_instance.zabbix.boot_disk[0].disk_id,
    yandex_compute_instance.elasticsearch.boot_disk[0].disk_id,
    yandex_compute_instance.kibana.boot_disk[0].disk_id,
  ]
}
