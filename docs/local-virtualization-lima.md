# Local Virtualization With Lima

Use this path when you want local Linux VMs that the Jetpack deploy role can
reach over SSH. Lima is the recommended local virtualization layer on macOS,
including Apple Silicon, because it can run ARM Linux guests directly and has a
scriptable CLI.

In this repo, "Jetpack" means the `riffcc/jetpack` automation used by the
`jetp` CLI. Lima does not emulate NVIDIA Jetson JetPack, CUDA, or Jetson GPU
hardware. For Jetson-specific validation, use real Jetson hardware or another
GPU-capable Linux host.

## Install Lima

Install Lima with Homebrew:

```bash
brew install lima
limactl --version
limactl start --list-templates | grep '^ubuntu-lts$'
```

The examples below use the `ubuntu-lts` template because the Expanso Edge role
supports Debian/Ubuntu and maps both `x86_64` and `aarch64` Linux guests to the
right Expanso release artifact.

## Install Jetpack On The Mac

Install the Jetpack CLI on the Mac that will run the playbook. Jetpack is the
controller; it connects to the Lima VMs over SSH. You do not need to install
Jetpack inside every VM.

Until prebuilt Jetpack binaries are published, build it from source:

```bash
git clone https://github.com/riffcc/jetpack.git ~/code/jetpack
cd ~/code/jetpack
cargo install --path .
```

Current upstream source builds a `jetpack` binary, while this repo's commands
use the `jetp` CLI name. If `jetp` is not present after install, add a local
symlink:

```bash
if ! command -v jetp >/dev/null 2>&1 && command -v jetpack >/dev/null 2>&1; then
  ln -sf "$(command -v jetpack)" "$HOME/.cargo/bin/jetp"
fi

jetp --version
```

## Create Five Local VMs

Create five Ubuntu VMs with stable SSH ports. The VM names match the committed
`edge` inventory host names, so the same Jetpack deploy playbook can target
them. Lima's `--memory` and `--disk` values are GiB.

```bash
case "$(uname -m)" in
  arm64) lima_arch=aarch64 ;;
  x86_64) lima_arch=x86_64 ;;
  *)
    echo "unsupported host architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

for node in 01 02 03 04 05; do
  port=$((60021 + 10#$node))
  name="expanso-edge-$node"

  limactl create \
    --tty=false \
    --name "$name" \
    --arch "$lima_arch" \
    --cpus 2 \
    --memory 4 \
    --disk 20 \
    --ssh-port "$port" \
    template:ubuntu-lts

  limactl start "$name"
done
```

Check the VMs:

```bash
limactl list

for node in 01 02 03 04 05; do
  port=$((60021 + 10#$node))
  ssh \
    -o StrictHostKeyChecking=accept-new \
    -i ~/.lima/_config/user \
    -p "$port" \
    "$USER@127.0.0.1" \
    'hostname; uname -m; systemctl --version | head -n 1'
done
```

## Add A Jetpack Overlay

The committed inventory still documents the Proxmox LXC provisioning example.
For Lima, do not run `deploy/playbooks/provision-proxmox-lxc.yml`. Instead,
start the VMs with Lima and add a gitignored secrets overlay that tells Jetpack
how to SSH into each VM.

```bash
cp -r deploy/secrets.example deploy/secrets
mkdir -p deploy/secrets/host_vars

for node in 01 02 03 04 05; do
  port=$((60021 + 10#$node))
  host="expanso-edge-$node"

  cat > "deploy/secrets/host_vars/$host" <<EOF
jet_ssh_hostname: 127.0.0.1
jet_ssh_port: $port
jet_ssh_user: "$USER"
jet_ssh_private_key_file: "~/.lima/_config/user"
EOF
done
```

Then edit `deploy/secrets/group_vars/edge` and set a real bootstrap token:

```yaml
expanso_bootstrap_token: "exp_bk_..."
```

Keep `deploy/secrets/` local. It is ignored by git because it contains
machine-specific SSH details and Expanso credentials.

## Deploy Expanso Edge

Run the normal deployment playbook. The role does not care whether the host was
created by Proxmox, Lima, a cloud provider, or bare metal as long as Jetpack can
SSH into it.

```bash
jetp ssh \
  --playbook deploy/playbooks/expanso-edge.yml \
  --inventory deploy/inventory \
  --inventory deploy/secrets \
  --roles deploy/roles
```

Verify from the VMs:

```bash
for node in 01 02 03 04 05; do
  port=$((60021 + 10#$node))
  ssh \
    -i ~/.lima/_config/user \
    -p "$port" \
    "$USER@127.0.0.1" \
    'sudo systemctl is-active expanso-edge && sudo systemctl status --no-pager expanso-edge | head -n 12'
done
```

## Stop Or Remove The VMs

Stop the VMs when you are done:

```bash
for node in 01 02 03 04 05; do
  limactl stop "expanso-edge-$node"
done
```

Delete them when you no longer need the local lab:

```bash
for node in 01 02 03 04 05; do
  limactl delete "expanso-edge-$node"
done
```

## Choosing A Local Layer

Use Lima for a local macOS lab that needs SSH-addressable Linux hosts. Use the
macOS-native edge helper when you only need multiple Expanso nodes registered in
the control plane and do not need OS isolation. Use Proxmox on a separate
x86_64 host when you need a persistent hypervisor with LXC or VM management.

References:

- Lima docs: <https://lima-vm.io/docs/>
- Lima installation: <https://lima-vm.io/docs/installation/>
