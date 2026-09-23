#!/usr/bin/env python3

import json
import os
import sys
import urllib.request
from pathlib import Path

API = os.environ.get("ZABBIX_API", "http://127.0.0.1:8080/api_jsonrpc.php")
TOKEN = os.environ.get("ZABBIX_API_TOKEN")
ALB_IP = os.environ.get("ALB_IP")

ROOT = Path(__file__).resolve().parents[2]
DASHBOARDS = ROOT / "ansible/roles/zabbix_bootstrap/files/dashboards"

if not TOKEN:
    sys.exit("ERROR: ZABBIX_API_TOKEN is not set")

if not ALB_IP:
    sys.exit("ERROR: ALB_IP is not set")

req_id = 0

def api(method, params):
    global req_id
    req_id += 1

    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
        "id": req_id
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
        raise RuntimeError(
            f"{method}: {json.dumps(data['error'], ensure_ascii=False)}"
        )

    return data["result"]


def get_one(method, params, name):
    result = api(method, params)
    if not result:
        raise RuntimeError(f"Not found: {name}")
    return result[0]


print("=== Resolve Zabbix objects ===")

linux_group = get_one(
    "hostgroup.get",
    {
        "output": ["groupid", "name"],
        "filter": {"name": ["Linux servers"]}
    },
    "Linux servers group"
)

linux_template = get_one(
    "template.get",
    {
        "output": ["templateid", "host"],
        "filter": {"host": ["Linux by Zabbix agent"]}
    },
    "Linux by Zabbix agent"
)

zabbix_host = get_one(
    "host.get",
    {
        "output": ["hostid", "host"],
        "filter": {"host": ["zabbix"]}
    },
    "zabbix host"
)

groupid = linux_group["groupid"]
templateid = linux_template["templateid"]
zabbix_hostid = zabbix_host["hostid"]

print("Linux group:", groupid)
print("Linux template:", templateid)
print("Zabbix host:", zabbix_hostid)


print("\n=== Autoregistration action ===")

action_name = "Linux hosts autoregistration"

actions = api(
    "action.get",
    {
        "output": ["actionid", "name"],
        "filter": {
            "name": [action_name]
        }
    }
)

if not actions:
    result = api(
        "action.create",
        {
            "name": action_name,
            "eventsource": 2,
            "status": 0,
            "filter": {
                "evaltype": 0,
                "conditions": []
            },
            "operations": [
                {
                    "operationtype": 2
                },
                {
                    "operationtype": 4,
                    "opgroup": [
                        {
                            "groupid": groupid
                        }
                    ]
                },
                {
                    "operationtype": 6,
                    "optemplate": [
                        {
                            "templateid": templateid
                        }
                    ]
                }
            ]
        }
    )

    print("Created action:", result["actionids"][0])
else:
    print("Action already exists:", actions[0]["actionid"])


print("\n=== Web scenario ===")

scenario_name = "Website via ALB"
alb_url = f"http://{ALB_IP}"

scenarios = api(
    "httptest.get",
    {
        "output": ["httptestid", "name"],
        "hostids": [zabbix_hostid],
        "filter": {
            "name": [scenario_name]
        },
        "selectSteps": ["url"]
    }
)

recreate = False

if scenarios:
    current = scenarios[0]
    steps = current.get("steps", [])
    current_url = steps[0]["url"] if steps else ""

    if current_url != alb_url:
        api("httptest.delete", [current["httptestid"]])
        recreate = True
        print("Removed old scenario")
    else:
        print("Scenario already correct:", current["httptestid"])
else:
    recreate = True

if recreate:
    result = api(
        "httptest.create",
        {
            "name": scenario_name,
            "hostid": zabbix_hostid,
            "delay": "1m",
            "retries": 2,
            "steps": [
                {
                    "name": "Homepage",
                    "no": 1,
                    "url": alb_url,
                    "status_codes": "200",
                    "timeout": "10s"
                }
            ]
        }
    )

    print("Created scenario:", result["httptestids"][0])


def load_dashboard(filename):
    path = DASHBOARDS / filename
    data = json.loads(path.read_text(encoding="utf-8"))

    # JSON должен быть переносимым между установками.
    for page in data.get("pages", []):
        for widget in page.get("widgets", []):
            for field in widget.get("fields", []):
                if field.get("value") == "__ZABBIX_HOSTID__":
                    field["value"] = zabbix_hostid

    # Эти поля не нужны при dashboard.create.
    data.pop("uuid", None)
    data.pop("users", None)
    data.pop("userGroups", None)

    return data


print("\n=== Dashboards ===")

for filename in (
    "use-dashboard.json",
    "http-dashboard.json",
):
    dashboard = load_dashboard(filename)
    name = dashboard["name"]

    existing = api(
        "dashboard.get",
        {
            "output": ["dashboardid", "name"],
            "filter": {
                "name": [name]
            }
        }
    )

    if existing:
        print(f"{name}: already exists ({existing[0]['dashboardid']})")
        continue

    result = api(
        "dashboard.create",
        dashboard
    )

    print(f"{name}: created ({result['dashboardids'][0]})")


print("\nBOOTSTRAP OK")
