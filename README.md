# jetpack-expanso

Deploy [Expanso Edge](https://expanso.io) agents with
[Jetpack](https://github.com/riffcc/jetpack): a reusable, target-agnostic role
plus an example provisioning recipe and inventory.

The role installs, bootstraps, and runs `expanso-edge` on any Debian/EL host. How
those hosts come into being — Proxmox LXC, a VM, a cloud instance, or bare metal
— is a per-host `provision:` detail in inventory, not something the deploy play
knows about. (Consumers like Dragonfly drive Jetpack as a Rust crate rather than
running these playbooks.)

## Layout

```
deploy/
  roles/expanso-edge/             # install + bootstrap + systemd (no curl|bash); runs anywhere
  playbooks/
    expanso-edge.yml             # the deploy — provision-agnostic (groups: edge, roles: expanso-edge)
    provision-proxmox-lxc.yml    # ONE recipe to stand up a fleet (instantiate); swap for VMs/cloud/etc.
  inventory/                      # committed, extensionless, NO secrets
    groups/edge                  #   the edge fleet
    groups/proxmox               #   the Proxmox API host for the LXC recipe
    group_vars/all               #   version, ostemplate, operator SSH key
    host_vars/expanso-edge-0N    #   per-host provision: blocks (the target detail)
  secrets.example/                # template for the secret overlay (copy -> secrets/)
```

Secrets never live in the committed inventory. They go in a separate overlay
inventory (`deploy/secrets/`, gitignored) that Jetpack merges on top:

- `secrets/host_vars/mrow` — Proxmox API credentials (for the LXC recipe)
- `secrets/group_vars/edge` — the Expanso Cloud bootstrap key (`exp_bk_…`)

## Run

```bash
cp -r deploy/secrets.example deploy/secrets   # then fill in real values

# Deploy to the edge fleet (each host self-provisions from its provision: block):
jetp ssh --playbook deploy/playbooks/expanso-edge.yml \
         --inventory deploy/inventory --inventory deploy/secrets \
         --roles deploy/roles
```

Inventories merge in the order given, so the secret overlay (last) wins on top of
the committed inventory. (`--inventory a:b` colon-syntax works too; repeating the
flag is clearer.)

To scaffold a fresh Proxmox LXC fleet first, run `provision-proxmox-lxc.yml` —
it writes the per-host `provision:` blocks and creates the containers. To target
VMs or bare metal instead, change the `provision:` blocks (or drop them); the
role and `expanso-edge.yml` don't change.

For a local macOS VM lab, see [Local Virtualization With
Lima](docs/local-virtualization-lima.md). It shows how to install Lima, create
five Ubuntu VMs, add a gitignored Jetpack SSH overlay, and run the same
`expanso-edge.yml` deploy playbook against those VMs.

Re-runs are idempotent: existing hosts are reused, the agent restarts only when
the version actually changes, and a node is bootstrapped exactly once (its
credentials file is the guard).
