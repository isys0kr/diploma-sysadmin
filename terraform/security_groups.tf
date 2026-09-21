# ============================================================
# Группы безопасности
# ============================================================


# ------------------------------------------------------------
# Bastion
# ------------------------------------------------------------

resource "yandex_vpc_security_group" "admin_bastion" {
  name        = "ssg-admin-bastion"
  description = "Группа безопасности Bastion"
  network_id  = yandex_vpc_network.diploma.id
}


# ------------------------------------------------------------
# Веб-серверы
# ------------------------------------------------------------

resource "yandex_vpc_security_group" "web" {
  name        = "ssg-web"
  description = "Группа безопасности веб-серверов"
  network_id  = yandex_vpc_network.diploma.id
}


# ------------------------------------------------------------
# Балансировщик нагрузки
# ------------------------------------------------------------

resource "yandex_vpc_security_group" "alb" {
  name        = "ssg-alb"
  description = "Группа безопасности ALB"
  network_id  = yandex_vpc_network.diploma.id
}


# ------------------------------------------------------------
# Zabbix
# ------------------------------------------------------------

resource "yandex_vpc_security_group" "zabbix" {
  name        = "ssg-zabbix"
  description = "Группа безопасности Zabbix"
  network_id  = yandex_vpc_network.diploma.id
}


# ------------------------------------------------------------
# Elasticsearch
# ------------------------------------------------------------

resource "yandex_vpc_security_group" "elasticsearch" {
  name        = "ssg-elasticsearch"
  description = "Группа безопасности Elasticsearch"
  network_id  = yandex_vpc_network.diploma.id
}


# ------------------------------------------------------------
# Kibana
# ------------------------------------------------------------

resource "yandex_vpc_security_group" "kibana" {
  name        = "ssg-kibana"
  description = "Группа безопасности Kibana"
  network_id  = yandex_vpc_network.diploma.id
}


# ============================================================
# Правила Bastion
# ============================================================

# SSH из Интернета к Bastion
resource "yandex_vpc_security_group_rule" "admin_ssh_in" {
  security_group_binding = yandex_vpc_security_group.admin_bastion.id

  direction      = "ingress"
  description    = "SSH"
  protocol       = "TCP"
  port           = 22
  v4_cidr_blocks = ["0.0.0.0/0"]
}


# Zabbix agent на Bastion
resource "yandex_vpc_security_group_rule" "admin_zabbix_agent_in" {
  security_group_binding = yandex_vpc_security_group.admin_bastion.id

  direction         = "ingress"
  description       = "Zabbix agent от сервера Zabbix"
  protocol          = "TCP"
  port              = 10050
  security_group_id = yandex_vpc_security_group.zabbix.id
}


# Исходящий трафик Bastion
resource "yandex_vpc_security_group_rule" "admin_egress_any" {
  security_group_binding = yandex_vpc_security_group.admin_bastion.id

  direction      = "egress"
  description    = "Внешний трафик"
  protocol       = "ANY"
  v4_cidr_blocks = ["0.0.0.0/0"]
}


# ============================================================
# Правила веб-серверов
# ============================================================

# SSH от Bastion to Веб-серверы
resource "yandex_vpc_security_group_rule" "web_ssh_from_admin" {
  security_group_binding = yandex_vpc_security_group.web.id

  direction         = "ingress"
  description       = "SSH от Bastion"
  protocol          = "TCP"
  port              = 22
  security_group_id = yandex_vpc_security_group.admin_bastion.id
}


# HTTP from Балансировщик нагрузки
resource "yandex_vpc_security_group_rule" "web_http_from_alb" {
  security_group_binding = yandex_vpc_security_group.web.id

  direction         = "ingress"
  description       = "HTTP от ALB"
  protocol          = "TCP"
  port              = 80
  security_group_id = yandex_vpc_security_group.alb.id
}


# Веб-интерфейс Zabbix
resource "yandex_vpc_security_group_rule" "zabbix_http_in" {
  security_group_binding = yandex_vpc_security_group.zabbix.id

  direction      = "ingress"
  description    = "Веб-интерфейс Zabbix"
  protocol       = "TCP"
  port           = 80
  v4_cidr_blocks = ["0.0.0.0/0"]
}

# Исходящий трафик веб-серверов через NAT
resource "yandex_vpc_security_group_rule" "web_egress_any" {
  security_group_binding = yandex_vpc_security_group.web.id

  direction      = "egress"
  description    = "Исходящий трафик через NAT"
  protocol       = "ANY"
  v4_cidr_blocks = ["0.0.0.0/0"]
}


# ============================================================
# Балансировщик нагрузки rules
# ============================================================

# Публичный HTTP
resource "yandex_vpc_security_group_rule" "alb_http_in" {
  security_group_binding = yandex_vpc_security_group.alb.id

  direction      = "ingress"
  description    = "Публичный HTTP"
  protocol       = "TCP"
  port           = 80
  v4_cidr_blocks = ["0.0.0.0/0"]
}


# Проверки состояния ALB
resource "yandex_vpc_security_group_rule" "alb_healthchecks_in" {
  security_group_binding = yandex_vpc_security_group.alb.id

  direction         = "ingress"
  description       = "Проверки состояния ALB"
  protocol          = "TCP"
  port              = 30080
  predefined_target = "loadbalancer_healthchecks"
}


# Исходящий трафик ALB
resource "yandex_vpc_security_group_rule" "alb_egress_any" {
  security_group_binding = yandex_vpc_security_group.alb.id

  direction      = "egress"
  description    = "Исходящий трафик ALB"
  protocol       = "ANY"
  v4_cidr_blocks = ["0.0.0.0/0"]
}


# ============================================================
# Правила Zabbix
# ============================================================

# SSH от Bastion
resource "yandex_vpc_security_group_rule" "zabbix_ssh_from_admin" {
  security_group_binding = yandex_vpc_security_group.zabbix.id

  direction         = "ingress"
  description       = "SSH от Bastion"
  protocol          = "TCP"
  port              = 22
  security_group_id = yandex_vpc_security_group.admin_bastion.id
}


# Приём данных Zabbix от агентов
resource "yandex_vpc_security_group_rule" "zabbix_server_in_from_bastion" {
  security_group_binding = yandex_vpc_security_group.zabbix.id

  direction         = "ingress"
  description       = "Zabbix от агента Bastion"
  protocol          = "TCP"
  port              = 10051
  security_group_id = yandex_vpc_security_group.admin_bastion.id
}


resource "yandex_vpc_security_group_rule" "zabbix_server_in_from_web" {
  security_group_binding = yandex_vpc_security_group.zabbix.id

  direction         = "ingress"
  description       = "Zabbix от веб-агентов"
  protocol          = "TCP"
  port              = 10051
  security_group_id = yandex_vpc_security_group.web.id
}


resource "yandex_vpc_security_group_rule" "zabbix_server_in_from_elasticsearch" {
  security_group_binding = yandex_vpc_security_group.zabbix.id

  direction         = "ingress"
  description       = "Zabbix от агента Elasticsearch"
  protocol          = "TCP"
  port              = 10051
  security_group_id = yandex_vpc_security_group.elasticsearch.id
}


resource "yandex_vpc_security_group_rule" "zabbix_server_in_from_kibana" {
  security_group_binding = yandex_vpc_security_group.zabbix.id

  direction         = "ingress"
  description       = "Zabbix от агента Kibana"
  protocol          = "TCP"
  port              = 10051
  security_group_id = yandex_vpc_security_group.kibana.id
}


# Zabbix agent на сервере Zabbix
resource "yandex_vpc_security_group_rule" "zabbix_agent_in" {
  security_group_binding = yandex_vpc_security_group.zabbix.id

  direction         = "ingress"
  description       = "Zabbix agent"
  protocol          = "TCP"
  port              = 10050
  security_group_id = yandex_vpc_security_group.zabbix.id
}


# Исходящий трафик Zabbix
resource "yandex_vpc_security_group_rule" "zabbix_egress_any" {
  security_group_binding = yandex_vpc_security_group.zabbix.id

  direction      = "egress"
  description    = "Исходящий трафик Zabbix"
  protocol       = "ANY"
  v4_cidr_blocks = ["0.0.0.0/0"]
}


# ============================================================
# Правила Elasticsearch
# ============================================================

# SSH от Bastion
resource "yandex_vpc_security_group_rule" "elasticsearch_ssh_from_admin" {
  security_group_binding = yandex_vpc_security_group.elasticsearch.id

  direction         = "ingress"
  description       = "SSH от Bastion"
  protocol          = "TCP"
  port              = 22
  security_group_id = yandex_vpc_security_group.admin_bastion.id
}


# Elasticsearch API from Веб-серверы / Filebeat
resource "yandex_vpc_security_group_rule" "elasticsearch_from_web" {
  security_group_binding = yandex_vpc_security_group.elasticsearch.id

  direction         = "ingress"
  description       = "API Elasticsearch от Filebeat"
  protocol          = "TCP"
  port              = 9200
  security_group_id = yandex_vpc_security_group.web.id
}


# API Elasticsearch от Kibana
resource "yandex_vpc_security_group_rule" "elasticsearch_from_kibana" {
  security_group_binding = yandex_vpc_security_group.elasticsearch.id

  direction         = "ingress"
  description       = "API Elasticsearch от Kibana"
  protocol          = "TCP"
  port              = 9200
  security_group_id = yandex_vpc_security_group.kibana.id
}


# Zabbix agent на Elasticsearch
resource "yandex_vpc_security_group_rule" "elasticsearch_zabbix_agent_in" {
  security_group_binding = yandex_vpc_security_group.elasticsearch.id

  direction         = "ingress"
  description       = "Zabbix agent от сервера Zabbix"
  protocol          = "TCP"
  port              = 10050
  security_group_id = yandex_vpc_security_group.zabbix.id
}


# Исходящий трафик Elasticsearch через NAT
resource "yandex_vpc_security_group_rule" "elasticsearch_egress_any" {
  security_group_binding = yandex_vpc_security_group.elasticsearch.id

  direction      = "egress"
  description    = "Исходящий трафик через NAT"
  protocol       = "ANY"
  v4_cidr_blocks = ["0.0.0.0/0"]
}


# ============================================================
# Правила Kibana
# ============================================================

# SSH от Bastion
resource "yandex_vpc_security_group_rule" "kibana_ssh_from_admin" {
  security_group_binding = yandex_vpc_security_group.kibana.id

  direction         = "ingress"
  description       = "SSH от Bastion"
  protocol          = "TCP"
  port              = 22
  security_group_id = yandex_vpc_security_group.admin_bastion.id
}


# Веб-интерфейс Kibana
resource "yandex_vpc_security_group_rule" "kibana_web_in" {
  security_group_binding = yandex_vpc_security_group.kibana.id

  direction      = "ingress"
  description    = "Веб-интерфейс Kibana"
  protocol       = "TCP"
  port           = 5601
  v4_cidr_blocks = ["0.0.0.0/0"]
}


# Zabbix agent на Kibana
resource "yandex_vpc_security_group_rule" "kibana_zabbix_agent_in" {
  security_group_binding = yandex_vpc_security_group.kibana.id

  direction         = "ingress"
  description       = "Zabbix agent от сервера Zabbix"
  protocol          = "TCP"
  port              = 10050
  security_group_id = yandex_vpc_security_group.zabbix.id
}


# Исходящий трафик Kibana
resource "yandex_vpc_security_group_rule" "kibana_egress_any" {
  security_group_binding = yandex_vpc_security_group.kibana.id

  direction      = "egress"
  description    = "Исходящий трафик Kibana"
  protocol       = "ANY"
  v4_cidr_blocks = ["0.0.0.0/0"]
}

# Zabbix agent на веб-серверах
resource "yandex_vpc_security_group_rule" "web_zabbix_agent_in" {
  security_group_binding = yandex_vpc_security_group.web.id

  direction         = "ingress"
  description       = "Zabbix agent от сервера Zabbix"
  protocol          = "TCP"
  port              = 10050
  security_group_id = yandex_vpc_security_group.zabbix.id
}
