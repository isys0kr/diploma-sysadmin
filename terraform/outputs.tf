output "network_id" {
  value = yandex_vpc_network.diploma.id
}

output "public_b_subnet_id" {
  value = yandex_vpc_subnet.public_b.id
}

output "private_b_subnet_id" {
  value = yandex_vpc_subnet.private_b.id
}

output "private_a_subnet_id" {
  value = yandex_vpc_subnet.private_a.id
}
output "admin_bastion_external_ip" {
  value = yandex_compute_instance.admin_bastion.network_interface[0].nat_ip_address
}

output "admin_bastion_internal_ip" {
  value = yandex_compute_instance.admin_bastion.network_interface[0].ip_address
}
