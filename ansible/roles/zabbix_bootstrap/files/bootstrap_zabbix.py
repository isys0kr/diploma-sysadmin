#!/usr/bin/env python3

import argparse
import json
import os
import sys
import time
import urllib.request
from pathlib import Path

API = "http://127.0.0.1/api_jsonrpc.php"
ADMIN_USER = "Admin"
ADMIN_PASSWORD = "zabbix"

EXPECTED_HOSTS = {
    "bast",
    "web-1",
    "web-2",
    "zabbix",
    "elasticsearch",
    "kibana",
}

req_id = 0
auth = None


def api(method, params=None, use_auth=True):
    global req_id, auth
    req_id += 1

    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params or {},
        "id": req_id,
    }

    if use_auth and auth:
        payload["auth"] = auth

    req = urllib.request.Request(
        API,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json-rpc"},
    )

    with urllib.request.urlopen(req, timeout=30) as response:
        data = json.loads(response.read().decode())

    if "error" in data:
        raise RuntimeError(
            f"{method}: {json.dumps(data['error'], ensure_ascii=False)}"
        )

    return data["result"]


def login():
    global auth

    auth = api(
        "user.login",
        {
            "username": ADMIN_USER,
            "password": ADMIN_PASSWORD,
        },
        use_auth=False,
    )


def logout():
    global auth

    if auth:
        try:
            api("user.logout", {})
        finally:
            auth = None


def get_one(method, params, description):
    result = api(method, params)

    if not result:
        raise RuntimeError(f"Not found: {description}")

    return result[0]


def prepare():
    print("=== PREPARE AUTOREGISTRATION ===")

    group = get_one(
        "hostgroup.get",
        {
            "output": ["groupid", "name"],
            "filter": {"name": ["Linux servers"]},
        },
        "Linux servers",
    )

    template = get_one(
        "template.get",
        {
            "output": ["templateid", "host"],
            "filter": {"host": ["Linux by Zabbix agent"]},
        },
        "Linux by Zabbix agent",
    )

    action_name = "Linux hosts autoregistration"

    actions = api(
        "action.get",
        {
            "output": ["actionid", "name"],
            "filter": {"name": [action_name]},
        },
    )

    if actions:
        print(f"Action already exists: {actions[0]['actionid']}")
        return

    result = api(
        "action.create",
        {
            "name": action_name,
            "eventsource": "2",
            "status": "0",
            "operations": [
                {
                    "operationtype": "2"
                },
                {
                    "operationtype": "4",
                    "opgroup": [
                        {
                            "groupid": group["groupid"]
                        }
                    ],
                },
                {
                    "operationtype": "6",
                    "optemplate": [
                        {
                            "templateid": template["templateid"]
                        }
                    ],
                },
            ],
        },
    )

    print(f"Created action: {result['actionids'][0]}")


def wait_for_hosts():
    print("=== WAIT FOR AUTOREGISTERED HOSTS ===")

    for attempt in range(1, 31):
        hosts = api(
            "host.get",
            {
                "output": ["hostid", "host"],
                "filter": {
                    "host": sorted(EXPECTED_HOSTS)
                },
            },
        )

        found = {h["host"] for h in hosts}
        missing = EXPECTED_HOSTS - found

        if not missing:
            print("All expected hosts are registered")
            return {h["host"]: h["hostid"] for h in hosts}

        print(
            f"Attempt {attempt}/30, waiting for: "
            + ", ".join(sorted(missing))
        )

        time.sleep(5)

    raise RuntimeError(
        "Autoregistration timeout. Missing: "
        + ", ".join(sorted(missing))
    )


def ensure_web_scenario(zabbix_hostid, alb_ip):
    print("=== WEB SCENARIO ===")

    name = "Website via ALB"
    url = f"http://{alb_ip}"

    scenarios = api(
        "httptest.get",
        {
            "output": ["httptestid", "name"],
            "hostids": [zabbix_hostid],
            "filter": {"name": [name]},
            "selectSteps": ["url"],
        },
    )

    if scenarios:
        current = scenarios[0]
        steps = current.get("steps", [])
        current_url = steps[0]["url"] if steps else ""

        if current_url == url:
            print(f"Scenario already correct: {current['httptestid']}")
            return

        api("httptest.delete", [current["httptestid"]])
        print("Removed outdated scenario")

    result = api(
        "httptest.create",
        {
            "name": name,
            "hostid": zabbix_hostid,
            "delay": "1m",
            "retries": 2,
            "steps": [
                {
                    "name": "Homepage",
                    "no": 1,
                    "url": url,
                    "status_codes": "200",
                    "timeout": "10s",
                }
            ],
        },
    )

    print(f"Created scenario: {result['httptestids'][0]}")


def load_dashboard(path, zabbix_hostid):
    data = json.loads(path.read_text(encoding="utf-8"))

    data.pop("dashboardid", None)
    data.pop("userid", None)
    data.pop("uuid", None)
    data.pop("users", None)
    data.pop("userGroups", None)

    for page in data.get("pages", []):
        page.pop("dashboard_pageid", None)

        for widget in page.get("widgets", []):
            widget.pop("widgetid", None)

            for field in widget.get("fields", []):
                if field.get("value") == "__ZABBIX_HOSTID__":
                    field["value"] = zabbix_hostid

    return data


def ensure_dashboard(path, zabbix_hostid):
    dashboard = load_dashboard(path, zabbix_hostid)
    name = dashboard["name"]

    existing = api(
        "dashboard.get",
        {
            "output": ["dashboardid", "name"],
            "filter": {"name": [name]},
        },
    )

    if existing:
        print(
            f"{name}: already exists "
            f"({existing[0]['dashboardid']})"
        )
        return

    result = api("dashboard.create", dashboard)

    print(
        f"{name}: created "
        f"({result['dashboardids'][0]})"
    )


def finalize(alb_ip, dashboards_dir):
    hostids = wait_for_hosts()

    ensure_web_scenario(
        hostids["zabbix"],
        alb_ip,
    )

    print("=== DASHBOARDS ===")

    ensure_dashboard(
        dashboards_dir / "use-dashboard.json",
        hostids["zabbix"],
    )

    ensure_dashboard(
        dashboards_dir / "http-dashboard.json",
        hostids["zabbix"],
    )

    print("BOOTSTRAP OK")


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "stage",
        choices=["prepare", "finalize"],
    )

    parser.add_argument(
        "--alb-ip",
    )

    parser.add_argument(
        "--dashboards-dir",
        default="/opt/zabbix-bootstrap/dashboards",
    )

    args = parser.parse_args()

    login()

    try:
        if args.stage == "prepare":
            prepare()

        else:
            if not args.alb_ip:
                sys.exit(
                    "ERROR: --alb-ip is required "
                    "for finalize"
                )

            finalize(
                args.alb_ip,
                Path(args.dashboards_dir),
            )

    finally:
        logout()


if __name__ == "__main__":
    main()
