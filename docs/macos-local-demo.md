# macOS Local Demo

Use this path when you want to run an Expanso Edge agent directly on a Mac,
without Proxmox, Docker, or a Linux VM.

## Prerequisites

- macOS arm64 or amd64.
- `expanso-edge` installed at `/usr/local/bin/expanso-edge`, or set
  `EXPANSO_EDGE_BIN`.
- `EXPANSO_EDGE_BOOTSTRAP_TOKEN` in `.env` for first-time bootstrap.
- Local edge credentials at `~/.expanso/edge/auth/credentials.creds`, or at
  `$EXPANSO_EDGE_DATA_DIR/auth/credentials.creds` if you set a custom data
  directory.

If credentials are missing, bootstrap once:

```bash
./scripts/run-local-macos.sh --bootstrap
```

## Run

Start the local agent in the foreground:

```bash
./scripts/run-local-macos.sh --verbose
```

The process stays attached to the terminal and prints connection logs. Press
Ctrl-C to stop it.

To check prerequisites without starting the agent:

```bash
./scripts/run-local-macos.sh --check
```

To keep it running in the background after the terminal exits:

```bash
./scripts/run-local-macos.sh --background --verbose
tail -f /tmp/jetpack-expanso/edge.log
```

Background mode uses `tmux` so the agent keeps the pseudo-terminal it expects.

Stop the background process with:

```bash
./scripts/run-local-macos.sh --stop-background
```

## Five Local Nodes

For a quick five-node Expanso demo on this Mac, you do not need Proxmox,
Docker, or a Linux VM. Run five isolated local agents instead:

```bash
./scripts/run-local-cluster-macos.sh --start
./scripts/run-local-cluster-macos.sh --status
```

The cluster helper uses separate credentials and state for each node:

- node 01: `.local/edge`, `localhost:9011`, tmux session
  `demo-jetpack-expanso-edge`
- node 02: `.local/edge-02`, `localhost:9012`, tmux session
  `demo-jetpack-expanso-edge-02`
- node 03: `.local/edge-03`, `localhost:9013`, tmux session
  `demo-jetpack-expanso-edge-03`
- node 04: `.local/edge-04`, `localhost:9014`, tmux session
  `demo-jetpack-expanso-edge-04`
- node 05: `.local/edge-05`, `localhost:9015`, tmux session
  `demo-jetpack-expanso-edge-05`

Stop all five local agents with:

```bash
./scripts/run-local-cluster-macos.sh --stop
```

This is a control-plane cluster demo, not a hardware isolation test. The nodes
appear separately to Expanso but share the same Mac CPU, memory, disk, and
hostname. Use lightweight ARM Linux VMs only when you need OS-level isolation.

## Verify

Use the Expanso CLI endpoint for the same control plane. The endpoint host
matches the `network_id` in `.local/edge/config.d/50-connection.yaml`.

```bash
set -a
source .env
set +a

expanso-cli node list \
  --endpoint "$EXPANSO_CLI_ENDPOINT" \
  --api-key "$EXPANSO_CLI_API_KEY" \
  --wide
```

A connected local Mac node should show the installed agent version and node
name. The five-node helper should show five separate node names.
