#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/terraform"
TPL="$ROOT_DIR/ansible/inventory/hosts.ini.tpl"
OUT="$ROOT_DIR/ansible/inventory/hosts.ini"

BASTION_IP="$(terraform -chdir="$TF_DIR" output -raw admin_bastion_external_ip)"

sed "s/BASTION_PUBLIC_IP/$BASTION_IP/g" "$TPL" > "$OUT"

echo "Inventory generated: $OUT"
echo "Bastion IP: $BASTION_IP"
