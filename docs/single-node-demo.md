# Single-Node Demo

Use this path when you already have one Debian, Ubuntu, or EL host reachable by
SSH and want the fastest demo of the `expanso-edge` role without provisioning a
Proxmox fleet.

## 1. Point the inventory at your host

Edit `deploy/inventory.single-node/host_vars/demo-edge-01`:

```yaml
hostname: demo-edge-01
jet_ssh_hostname: 192.0.2.10
jet_ssh_user: root
jet_ssh_port: 22
```

Use a real IP address or DNS name for `jet_ssh_hostname`. If your SSH key is not
loaded in the agent, pass Jetpack the key file on the command line.

## 2. Add the Expanso bootstrap token

Copy the secret overlay and replace the placeholder bootstrap key:

```bash
cp -r deploy/secrets.example deploy/secrets
$EDITOR deploy/secrets/group_vars/edge
```

The value should be an Expanso Cloud bootstrap key:

```yaml
expanso_bootstrap_token: "exp_bk_..."
```

## 3. Validate the demo inventory

```bash
jetp inventory-check --inventory deploy/inventory.single-node:deploy/secrets

jetp full-check \
  --playbook deploy/playbooks/expanso-edge.yml \
  --inventory deploy/inventory.single-node:deploy/secrets \
  --roles deploy/roles
```

## 4. Deploy the agent

```bash
jetp ssh \
  --playbook deploy/playbooks/expanso-edge.yml \
  --inventory deploy/inventory.single-node:deploy/secrets \
  --roles deploy/roles \
  --limit-hosts demo-edge-01
```

The role installs the configured `expanso-edge` release, bootstraps the host to
Expanso Cloud, installs the systemd unit, and starts the service.
