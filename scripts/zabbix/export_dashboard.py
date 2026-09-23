#!/usr/bin/env python3

import json
import os
import sys
import urllib.request
from pathlib import Path

API = "http://127.0.0.1:8080/api_jsonrpc.php"
TOKEN = os.environ.get("ZABBIX_API_TOKEN")

if not TOKEN:
    sys.exit("ERROR: ZABBIX_API_TOKEN is not set")

if len(sys.argv) != 3:
    sys.exit("Usage: export_dashboard.py 'Dashboard name' output.json")

dashboard_name = sys.argv[1]
output_file = Path(sys.argv[2])

payload = {
    "jsonrpc": "2.0",
    "method": "dashboard.get",
    "params": {
        "output": "extend",
        "selectPages": "extend",
        "selectUsers": "extend",
        "selectUserGroups": "extend",
        "filter": {
            "name": [dashboard_name]
        }
    },
    "id": 1
}

req = urllib.request.Request(
    API,
    data=json.dumps(payload).encode(),
    headers={
        "Content-Type": "application/json-rpc",
        "Authorization": f"Bearer {TOKEN}"
    }
)

with urllib.request.urlopen(req, timeout=30) as response:
    data = json.loads(response.read().decode())

if "error" in data:
    sys.exit(json.dumps(data["error"], indent=2))

result = data["result"]

if len(result) != 1:
    sys.exit(f"Expected exactly one dashboard '{dashboard_name}', found {len(result)}")

dashboard = result[0]

# ID текущей установки при импорте нам не нужен.
dashboard.pop("dashboardid", None)

# Владелец текущей установки тоже будет определяться заново.
dashboard.pop("userid", None)

# Эти ID генерируются заново при создании.
for page in dashboard.get("pages", []):
    page.pop("dashboard_pageid", None)

    for widget in page.get("widgets", []):
        widget.pop("widgetid", None)

output_file.parent.mkdir(parents=True, exist_ok=True)

output_file.write_text(
    json.dumps(dashboard, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8"
)

print(f"Exported: {dashboard_name}")
print(f"File: {output_file}")
