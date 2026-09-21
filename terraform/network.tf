resource "yandex_vpc_network" "diploma" {
  name        = "diploma-network"
  description = "Сеть дипломного проекта"
}

resource "yandex_vpc_subnet" "public_b" {
  name           = "public-b"
  description    = "Публичная подсеть ru-central1-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.diploma.id
  v4_cidr_blocks = ["10.10.10.0/24"]
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "private-b"
  description    = "Приватная подсеть ru-central1-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.diploma.id
  v4_cidr_blocks = ["10.10.20.0/24"]
  route_table_id = yandex_vpc_route_table.private.id
}

resource "yandex_vpc_subnet" "private_a" {
  name           = "private-a"
  description    = "Приватная подсеть ru-central1-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.diploma.id
  v4_cidr_blocks = ["10.10.30.0/24"]
  route_table_id = yandex_vpc_route_table.private.id
}
