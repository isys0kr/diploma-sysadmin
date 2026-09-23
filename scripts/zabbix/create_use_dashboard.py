#!/usr/bin/env python3

import json
import os
import urllib.request
import sys

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
        result = json.loads(response.read().decode())

    if "error" in result:
        raise RuntimeError(json.dumps(result["error"], ensure_ascii=False, indent=2))

    return result["result"]


HOSTS = [
    "bast",
    "web-1",
    "web-2",
    "zabbix",
    "elasticsearch",
    "kibana",
]


def dataset(hosts, items, color, index=0):
    fields = [
        {
            "type": 0,
            "name": f"ds.{index}.dataset_type",
            "value": 1,
        },
        {
            "type": 1,
            "name": f"ds.{index}.color",
            "value": color,
        },
    ]

    for n, host in enumerate(hosts):
        fields.append({
            "type": 1,
            "name": f"ds.{index}.hosts.{n}",
            "value": host,
        })

    for n, item in enumerate(items):
        fields.append({
            "type": 1,
            "name": f"ds.{index}.items.{n}",
            "value": item,
        })

    return fields


def graph(name, x, y, reference, datasets):
    fields = [
        {
            "type": 1,
            "name": "reference",
            "value": reference,
        },
        {
            "type": 0,
            "name": "rf_rate",
            "value": 60,
        },
    ]

    for ds in datasets:
        fields.extend(ds)

    return {
        "type": "svggraph",
        "name": name,
        "x": x,
        "y": y,
        "width": 36,
        "height": 5,
        "view_mode": 0,
        "fields": fields,
    }


# Удаляем старый тестовый USE Dashboard, если он уже существует.
existing = api("dashboard.get", {
    "output": ["dashboardid", "name"],
    "filter": {
        "name": ["USE Dashboard", "USE dashboard"]
    }
})

if existing:
    ids = [d["dashboardid"] for d in existing]
    print("Removing existing dashboard:", ", ".join(ids))
    api("dashboard.delete", ids)


widgets = [
    graph(
        "CPU utilization",
        0, 0,
        "CPU01",
        [
            dataset(
                HOSTS,
                ["*CPU utilization*"],
                "1E88E5",
            )
        ],
    ),

    graph(
        "Memory utilization",
        36, 0,
        "MEM01",
        [
            dataset(
                HOSTS,
                ["*Memory utilization*"],
                "43A047",
            )
        ],
    ),

    graph(
        "Disk utilization",
        0, 5,
        "DSK01",
        [
            dataset(
                HOSTS,
                [
                    "*Space: Used, in %*",
                ],
                "FB8C00",
            )
        ],
    ),

    graph(
        "Network traffic",
        36, 5,
        "NET01",
        [
            dataset(
                HOSTS,
                ["*Bits received*"],
                "8E24AA",
                0,
            ),
            dataset(
                HOSTS,
                ["*Bits sent*"],
                "E53935",
                1,
            ),
        ],
    ),
]


result = api("dashboard.create", {
    "name": "USE Dashboard",
    "display_period": 30,
    "auto_start": 1,
    "pages": [
        {
            "name": "USE",
            "widgets": widgets,
        }
    ],
})

print("Created USE Dashboard")
print("dashboardid:", result["dashboardids"][0])
