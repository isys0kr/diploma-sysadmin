#!/usr/bin/env python3

import json
import os
import sys
import urllib.request

API = "http://127.0.0.1:8080/api_jsonrpc.php"
TOKEN = os.environ.get("ZABBIX_API_TOKEN")

if not TOKEN:
    sys.exit("ERROR: ZABBIX_API_TOKEN is not set")

req_id = 0

def api(method, params):
    global req_id
    req_id += 1

    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
        "id": req_id,
    }

    req = urllib.request.Request(
        API,
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json-rpc",
            "Authorization": f"Bearer {TOKEN}",
        },
    )

    with urllib.request.urlopen(req, timeout=30) as response:
        data = json.loads(response.read().decode())

    if "error" in data:
        raise RuntimeError(json.dumps(data["error"], ensure_ascii=False, indent=2))

    return data["result"]


# Берём hostid zabbix-хоста
hosts = api("host.get", {
    "output": ["hostid", "host"],
    "filter": {
        "host": ["zabbix"]
    }
})

if not hosts:
    sys.exit("ERROR: host 'zabbix' not found")

hostid = hosts[0]["hostid"]

# Получаем IP ALB из переменной окружения
alb_ip = os.environ.get("ALB_IP")
if not alb_ip:
    sys.exit("ERROR: ALB_IP is not set")

url = f"http://{alb_ip}"

# Пересоздаём web scenario
existing = api("httptest.get", {
    "output": ["httptestid", "name"],
    "hostids": [hostid],
    "filter": {
        "name": ["Website via ALB"]
    }
})

if existing:
    api("httptest.delete", [x["httptestid"] for x in existing])

result = api("httptest.create", {
    "name": "Website via ALB",
    "hostid": hostid,
    "delay": "1m",
    "retries": 2,
    "steps": [
        {
            "name": "Homepage",
            "no": 1,
            "url": url,
            "status_codes": "200",
            "timeout": "10s"
        }
    ]
})

print("Created web scenario:", result["httptestids"][0])

# Удаляем старый HTTP Dashboard
existing = api("dashboard.get", {
    "output": ["dashboardid", "name"],
    "filter": {
        "name": ["HTTP Dashboard", "HTTP dashboard"]
    }
})

if existing:
    api("dashboard.delete", [x["dashboardid"] for x in existing])

# Создаём dashboard
result = api("dashboard.create", {
    "name": "HTTP Dashboard",
    "display_period": 30,
    "auto_start": 1,
    "pages": [
        {
            "name": "HTTP",
            "widgets": [
                {
                    "type": "web",
                    "name": "Website availability",
                    "x": 0,
                    "y": 0,
                    "width": 72,
                    "height": 6,
                    "view_mode": 0,
                    "fields": [
                        {
                            "type": 3,
                            "name": "hostids.0",
                            "value": hostid
                        },
                        {
                            "type": 1,
                            "name": "reference",
                            "value": "WEB01"
                        }
                    ]
                }
            ]
        }
    ]
})

print("Created HTTP Dashboard")
print("dashboardid:", result["dashboardids"][0])
