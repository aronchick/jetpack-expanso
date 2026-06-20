# jetpack-expanso

Deploy [Expanso Edge](https://expanso.io) agents with
[Jetpack](https://github.com/riffcc/jetpack).

This repo contains a reusable `expanso-edge` role plus example inventory and a
Proxmox LXC provisioning recipe. The deploy playbook is target-agnostic: a host
can come from Proxmox LXC, a VM, a cloud instance, or bare metal as long as the
inventory describes how Jetpack should reach it.

## Layout

```text
deploy/
  roles/expanso-edge/              # install, bootstrap, and run expanso-edge
  playbooks/
    expanso-edge.yml               # deploy to the edge fleet
    provision-proxmox-lxc.yml      # optional Proxmox LXC provisioning recipe
  inventory/                       # committed inventory, no secrets
    groups/edge
    groups/proxmox
    group_vars/all
    host_vars/expanso-edge-0N
  secrets.example/                 # copy to deploy/secrets and fill in
scripts/
  check.sh                         # local validation wrapper
```

## Validate

Run the local validation wrapper before changing inventory or roles:

```bash
./scripts/check.sh
```

The wrapper looks for `jetp` or `jetpack` on `PATH`. If you built Jetpack from
source or keep it elsewhere, set `JETPACK_BIN`:

```bash
JETPACK_BIN=/path/to/jetpack ./scripts/check.sh
```

It runs Jetpack syntax checks for both playbooks, validates the committed
inventory with `deploy/secrets.example`, and runs full checks for both
playbook/inventory combinations.

## Secrets

Secrets never live in the committed inventory. Copy the example overlay and
replace the placeholders:

```bash
cp -r deploy/secrets.example deploy/secrets
```

Expected local-only secret files:

```text
deploy/secrets/host_vars/mrow      # Proxmox API credentials
deploy/secrets/group_vars/edge     # Expanso Cloud bootstrap key
```

Jetpack merges inventories in order, so the secret overlay should be last:

```bash
jetp ssh \
  --playbook deploy/playbooks/expanso-edge.yml \
  --inventory deploy/inventory:deploy/secrets \
  --roles deploy/roles
```

## Provision Proxmox LXC Hosts

To scaffold the example Proxmox LXC fleet first, run the provisioning playbook:

```bash
jetp ssh \
  --playbook deploy/playbooks/provision-proxmox-lxc.yml \
  --inventory deploy/inventory:deploy/secrets \
  --roles deploy/roles
```

The provisioning playbook writes per-host `provision:` blocks and creates the
containers. To target VMs or bare metal, change or remove the `provision:`
blocks; the `expanso-edge` role and deploy playbook stay the same.

Re-runs are intended to be idempotent. Existing hosts are reused, the agent
restarts only when the version changes, and a node is bootstrapped exactly once
because its credentials file is the guard.
