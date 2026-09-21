resource "yandex_vpc_gateway" "nat" {
  name        = "diploma-nat-gateway"
  description = "NAT-шлюз для приватных подсетей"

  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "private" {
  name        = "private-route-table"
  description = "Маршрут приватных подсетей через NAT"
  network_id  = yandex_vpc_network.diploma.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}
