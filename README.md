# jetpack-expanso

Deploy [Expanso Edge](https://expanso.io) agents on Dragonfly with
[Jetpack](https://github.com/riffcc/jetpack) — provision the nodes on Proxmox and
install, bootstrap, and run `expanso-edge` on each, in a single idempotent run.

## Layout

```
deploy/
  roles/expanso-edge/      # download + bootstrap + systemd, Jetpack-native (no curl|bash)
  playbooks/dragonfly.yml  # provision 5 LXC on Proxmox + deploy the role
  inventory/               # committed, NO secrets
    groups/edge            #   the edge fleet (instantiate writes hosts here)
    groups/proxmox         #   the Proxmox API host (mrow)
    group_vars/all         #   version, ostemplate, operator SSH key
    host_vars/expanso-edge-0N   #   per-node provision blocks
  secrets.example/         # template for the secret overlay (copy -> secrets/)
```

Secrets never live in the committed inventory. They go in a separate overlay
inventory (`deploy/secrets/`, gitignored) that Jetpack merges on top:

- `secrets/host_vars/mrow` — Proxmox API credentials
- `secrets/group_vars/edge` — the Expanso Cloud bootstrap key (`exp_bk_…`)

## Run

```bash
cp -r deploy/secrets.example deploy/secrets   # then fill in real values
jetp ssh --playbook deploy/playbooks/dragonfly.yml \
         --inventory deploy/inventory --inventory deploy/secrets \
         --roles deploy/roles
```

Inventories are merged in the order given, so the secret overlay (last) wins on
top of the `edge` group and `mrow` host defined in the committed inventory.
(`--inventory a:b` colon-syntax works too, but repeating the flag is clearer.)

Re-runs are idempotent: existing containers are reused, the agent is only
restarted when the binary/version actually changes, and a node is bootstrapped
exactly once (the presence of its credentials file is the guard).
