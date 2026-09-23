[bastion]
bast ansible_host=BASTION_PUBLIC_IP

[web]
web-1 ansible_host=web-1-test.ru-central1.internal
web-2 ansible_host=web-2-test.ru-central1.internal

[zabbix_servers]
zabbix ansible_host=zabbix-host.ru-central1.internal

[elasticsearch_servers]
elasticsearch ansible_host=elasticsearch-host.ru-central1.internal

[kibana_servers]
kibana ansible_host=kibana-host.ru-central1.internal

[via_bastion:children]
web
zabbix_servers
elasticsearch_servers
kibana_servers

[all:vars]
ansible_user=isys
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_private_key_file=~/.ssh/diploma_ed25519

[via_bastion:vars]
ansible_ssh_common_args=-o StrictHostKeyChecking=accept-new -o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -i ~/.ssh/diploma_ed25519 -W %h:%p isys@BASTION_PUBLIC_IP"
