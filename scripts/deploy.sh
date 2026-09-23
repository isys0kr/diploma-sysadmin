#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Terraform apply ==="
terraform -chdir="$ROOT_DIR/terraform" apply

echo
echo "=== Generate Ansible inventory ==="
"$ROOT_DIR/scripts/generate_inventory.sh"

BASTION_IP="$(terraform -chdir="$ROOT_DIR/terraform" output -raw admin_bastion_external_ip)"
ALB_IP="$(terraform -chdir="$ROOT_DIR/terraform" output -raw alb_external_ip)"

echo
echo "=== Wait for Bastion SSH ==="

ssh-keygen -R "$BASTION_IP" >/dev/null 2>&1 || true

for i in $(seq 1 30); do
  if ssh \
    -o BatchMode=yes \
    -o ConnectTimeout=5 \
    -o ConnectionAttempts=1 \
    -o StrictHostKeyChecking=accept-new \
    -i ~/.ssh/diploma_ed25519 \
    isys@"$BASTION_IP" true 2>/dev/null
  then
    echo "Bastion SSH is ready: $BASTION_IP"
    break
  fi

  if [ "$i" -eq 30 ]; then
    echo "ERROR: Bastion SSH did not become ready: $BASTION_IP"
    exit 1
  fi

  echo "Waiting for Bastion SSH... attempt $i/30"
  sleep 10
done

echo
echo "=== Ansible deploy ==="
cd "$ROOT_DIR/ansible"

ansible-playbook \
  playbooks/site.yml \
  -e "alb_external_ip=$ALB_IP"
