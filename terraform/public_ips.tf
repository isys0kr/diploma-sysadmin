resource "yandex_vpc_address" "bastion_public" {
  name = "diploma-bastion-public-ip"

  external_ipv4_address {
    zone_id = "ru-central1-b"
  }
}
