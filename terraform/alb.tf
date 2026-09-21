# ============================================================
# Балансировщик нагрузки
# ============================================================


# ------------------------------------------------------------
# Целевая группа: web-1 + web-2
# ------------------------------------------------------------

resource "yandex_alb_target_group" "web" {
  name = "web-target-group"

  target {
    subnet_id  = yandex_vpc_subnet.private_b.id
    ip_address = yandex_compute_instance.web_1.network_interface[0].ip_address
  }

  target {
    subnet_id  = yandex_vpc_subnet.private_a.id
    ip_address = yandex_compute_instance.web_2.network_interface[0].ip_address
  }
}


# ------------------------------------------------------------
# Группа бэкендов
# ------------------------------------------------------------

resource "yandex_alb_backend_group" "web" {
  name = "web-backend-group"

  http_backend {
    name   = "web-http-backend"
    weight = 1
    port   = 80
    target_group_ids = [
      yandex_alb_target_group.web.id
    ]

    load_balancing_config {
      panic_threshold = 50
    }

    healthcheck {
      timeout  = "2s"
      interval = "5s"

      http_healthcheck {
        path = "/"
      }

      healthcheck_port = 80
    }
  }
}


# ------------------------------------------------------------
# HTTP-роутер
# ------------------------------------------------------------

resource "yandex_alb_http_router" "web" {
  name = "web-http-router"
}


# ------------------------------------------------------------
# Виртуальный хост
# ------------------------------------------------------------

resource "yandex_alb_virtual_host" "web" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.web.id

  route {
    name = "web-route"

    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web.id
        timeout          = "3s"
      }
    }
  }
}


# ------------------------------------------------------------
# Балансировщик нагрузки
# ------------------------------------------------------------

resource "yandex_alb_load_balancer" "web" {
  name       = "web-alb"
  network_id = yandex_vpc_network.diploma.id

  security_group_ids = [
    yandex_vpc_security_group.alb.id
  ]

  allocation_policy {
    location {
      zone_id   = "ru-central1-b"
      subnet_id = yandex_vpc_subnet.public_b.id
    }
  }

  listener {
    name = "web-listener"

    endpoint {
      address {
        external_ipv4_address {}
      }

      ports = [80]
    }

    http {
      handler {
        http_router_id = yandex_alb_http_router.web.id
      }
    }
  }
}
