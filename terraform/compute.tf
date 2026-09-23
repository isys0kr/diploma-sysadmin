
# cloud-init

locals {
  ubuntu_image_id  = "fd8nj6iro13qffg31not"
  common_user_data = <<-EOF
    #cloud-config

    users:
      - default
      - name: isys
        groups:
          - sudo
        shell: /bin/bash
        sudo:
          - ALL=(ALL) NOPASSWD:ALL
        ssh_authorized_keys:
          - ${trimspace(file(pathexpand("~/.ssh/diploma_ed25519.pub")))}

    ssh_pwauth: false

    runcmd:
      - systemctl enable ssh
      - systemctl restart ssh
      - ufw disable || true
  EOF
}


# Bastion

resource "yandex_compute_instance" "admin_bastion" {
  allow_stopping_for_update = true
  name                      = "bast"
  hostname                  = "bastion-serv"
  description               = "Точка входа"

  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = false
  }

  boot_disk {
    auto_delete = true

    initialize_params {
      image_id = local.ubuntu_image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public_b.id
    nat       = true

    security_group_ids = [
      yandex_vpc_security_group.admin_bastion.id
    ]
  }

  metadata = {
    enable-oslogin = "false"
    user-data      = local.common_user_data
  }
}


# Веб-сервер 1

resource "yandex_compute_instance" "web_1" {
  allow_stopping_for_update = true
  name                      = "web-1"
  hostname                  = "web-1-test"
  description               = "Веб-сервер 1"

  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = false
  }

  boot_disk {
    auto_delete = true

    initialize_params {
      image_id = local.ubuntu_image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private_b.id
    nat       = false

    security_group_ids = [
      yandex_vpc_security_group.web.id
    ]
  }

  metadata = {
    enable-oslogin = "false"
    user-data      = local.common_user_data
  }
}


# Веб-сервер 2

resource "yandex_compute_instance" "web_2" {
  allow_stopping_for_update = true
  name                      = "web-2"
  hostname                  = "web-2-test"
  description               = "Веб-сервер 2"

  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = false
  }

  boot_disk {
    auto_delete = true

    initialize_params {
      image_id = local.ubuntu_image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private_a.id
    nat       = false

    security_group_ids = [
      yandex_vpc_security_group.web.id
    ]
  }

  metadata = {
    enable-oslogin = "false"
    user-data      = local.common_user_data
  }
}


# Сервер Zabbix

resource "yandex_compute_instance" "zabbix" {
  allow_stopping_for_update = true
  name                      = "zabbix"
  hostname                  = "zabbix-host"
  description               = "Хост сервера мониторинга"

  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = false
  }

  boot_disk {
    auto_delete = true

    initialize_params {
      image_id = local.ubuntu_image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public_b.id
    nat       = true

    security_group_ids = [
      yandex_vpc_security_group.zabbix.id
    ]
  }

  metadata = {
    enable-oslogin = "false"
    user-data      = local.common_user_data
  }
}


# Elasticsearch

resource "yandex_compute_instance" "elasticsearch" {
  allow_stopping_for_update = true
  name                      = "elasticsearch"
  hostname                  = "elasticsearch-host"
  description               = "Сервер Elasticsearch"

  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = false
  }

  boot_disk {
    auto_delete = true

    initialize_params {
      image_id = local.ubuntu_image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private_b.id
    nat       = false

    security_group_ids = [
      yandex_vpc_security_group.elasticsearch.id
    ]
  }

  metadata = {
    enable-oslogin = "false"
    user-data      = local.common_user_data
  }
}


# Kibana

resource "yandex_compute_instance" "kibana" {
  allow_stopping_for_update = true
  name                      = "kibana"
  hostname                  = "kibana-host"
  description               = "Хост Kibana"

  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = false
  }

  boot_disk {
    auto_delete = true

    initialize_params {
      image_id = local.ubuntu_image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public_b.id
    nat       = true

    security_group_ids = [
      yandex_vpc_security_group.kibana.id
    ]
  }

  metadata = {
    enable-oslogin = "false"
    user-data      = local.common_user_data
  }
}
