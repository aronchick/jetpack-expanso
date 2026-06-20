#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

find_jetpack() {
  if [[ -n "${JETPACK_BIN:-}" ]]; then
    printf '%s\n' "$JETPACK_BIN"
    return 0
  fi

  if command -v jetp >/dev/null 2>&1; then
    command -v jetp
    return 0
  fi

  if command -v jetpack >/dev/null 2>&1; then
    command -v jetpack
    return 0
  fi

  printf 'error: set JETPACK_BIN or install jetp/jetpack on PATH\n' >&2
  return 127
}

JETPACK_BIN="$(find_jetpack)"
ROLES="deploy/roles"
INVENTORY="deploy/inventory:deploy/secrets.example"

run() {
  printf '\n==> %s\n' "$*"
  "$JETPACK_BIN" "$@"
}

run syntax-check \
  --playbook deploy/playbooks/expanso-edge.yml \
  --roles "$ROLES"

run syntax-check \
  --playbook deploy/playbooks/provision-proxmox-lxc.yml \
  --roles "$ROLES"

run inventory-check \
  --inventory "$INVENTORY"

run full-check \
  --playbook deploy/playbooks/expanso-edge.yml \
  --inventory "$INVENTORY" \
  --roles "$ROLES"

run full-check \
  --playbook deploy/playbooks/provision-proxmox-lxc.yml \
  --inventory "$INVENTORY" \
  --roles "$ROLES"
