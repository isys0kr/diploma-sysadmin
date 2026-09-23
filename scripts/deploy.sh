#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Terraform apply ==="
terraform -chdir="$ROOT_DIR/terraform" apply

echo
echo "=== Generate Ansible inventory ==="
"$ROOT_DIR/scripts/generate_inventory.sh"

echo
echo "=== Ansible deploy ==="
cd "$ROOT_DIR/ansible"
ansible-playbook playbooks/site.yml
