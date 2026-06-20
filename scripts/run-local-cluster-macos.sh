#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_LOCAL="$SCRIPT_DIR/run-local-macos.sh"

COUNT="${EXPANSO_EDGE_CLUSTER_COUNT:-5}"
BASE_PORT="${EXPANSO_EDGE_CLUSTER_BASE_PORT:-9010}"
DEMO_NAME="${EXPANSO_EDGE_CLUSTER_NAME:-$(basename "$REPO_ROOT")}"
TMP_DIR="${EXPANSO_EDGE_CLUSTER_TMP_DIR:-/tmp/$DEMO_NAME}"
MODE="start"
BOOTSTRAP=1

usage() {
  cat <<USAGE
Usage: $0 [--start|--stop|--status] [--count N] [--base-port PORT] [--no-bootstrap]

Runs multiple local macOS Expanso Edge agents without VMs. Each node gets its
own data directory, tmux session, API port, log file, and PID file.

Defaults:
  count:     $COUNT
  base port: $BASE_PORT  (node 01 listens on localhost:$((BASE_PORT + 1)))
  name:      $DEMO_NAME
  tmp dir:   $TMP_DIR

Environment overrides:
  EXPANSO_EDGE_CLUSTER_COUNT
  EXPANSO_EDGE_CLUSTER_BASE_PORT
  EXPANSO_EDGE_CLUSTER_NAME
  EXPANSO_EDGE_CLUSTER_TMP_DIR
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start)
      MODE="start"
      shift
      ;;
    --stop)
      MODE="stop"
      shift
      ;;
    --status)
      MODE="status"
      shift
      ;;
    --count)
      COUNT="${2:?missing value for --count}"
      shift 2
      ;;
    --base-port)
      BASE_PORT="${2:?missing value for --base-port}"
      shift 2
      ;;
    --no-bootstrap)
      BOOTSTRAP=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [[ "$COUNT" -lt 1 ]]; then
  echo "error: --count must be a positive integer" >&2
  exit 1
fi

if ! [[ "$BASE_PORT" =~ ^[0-9]+$ ]] || [[ "$BASE_PORT" -lt 1 ]]; then
  echo "error: --base-port must be a positive integer" >&2
  exit 1
fi

node_label() {
  printf "%02d" "$1"
}

node_data_dir() {
  local label="$1"
  if [[ "$label" == "01" ]]; then
    printf "%s/.local/edge" "$REPO_ROOT"
  else
    printf "%s/.local/edge-%s" "$REPO_ROOT" "$label"
  fi
}

node_session() {
  local label="$1"
  if [[ "$label" == "01" ]]; then
    printf "%s-edge" "$DEMO_NAME"
  else
    printf "%s-edge-%s" "$DEMO_NAME" "$label"
  fi
}

node_log_file() {
  local label="$1"
  if [[ "$label" == "01" ]]; then
    printf "%s/edge.log" "$TMP_DIR"
  else
    printf "%s/edge-%s.log" "$TMP_DIR" "$label"
  fi
}

node_pid_file() {
  local label="$1"
  if [[ "$label" == "01" ]]; then
    printf "%s/edge.pid" "$TMP_DIR"
  else
    printf "%s/edge-%s.pid" "$TMP_DIR" "$label"
  fi
}

node_name() {
  local label="$1"
  if [[ "$label" == "01" ]]; then
    printf "%s-local" "$DEMO_NAME"
  else
    printf "%s-node-%s" "$DEMO_NAME" "$label"
  fi
}

start_node() {
  local index="$1"
  local label data_dir session log_file pid_file port name

  label="$(node_label "$index")"
  data_dir="$(node_data_dir "$label")"
  session="$(node_session "$label")"
  log_file="$(node_log_file "$label")"
  pid_file="$(node_pid_file "$label")"
  port=$((BASE_PORT + index))
  name="$(node_name "$label")"

  echo "Starting node $label: name=$name api=localhost:$port data_dir=$data_dir"
  if [[ "$BOOTSTRAP" == "1" && ! -f "$data_dir/auth/credentials.creds" ]]; then
    EXPANSO_EDGE_DATA_DIR="$data_dir" "$RUN_LOCAL" --bootstrap
  fi

  if [[ ! -f "$data_dir/auth/credentials.creds" ]]; then
    echo "error: node $label is missing credentials at $data_dir/auth/credentials.creds" >&2
    echo "Set EXPANSO_EDGE_BOOTSTRAP_TOKEN or rerun without --no-bootstrap." >&2
    exit 1
  fi

  EXPANSO_EDGE_DATA_DIR="$data_dir" \
  EXPANSO_EDGE_TMUX_SESSION="$session" \
  EXPANSO_EDGE_LOG="$log_file" \
  EXPANSO_EDGE_PID="$pid_file" \
    "$RUN_LOCAL" --background --verbose --name "$name" --api-listen "localhost:$port"
}

stop_node() {
  local index="$1"
  local label data_dir session log_file pid_file

  label="$(node_label "$index")"
  data_dir="$(node_data_dir "$label")"
  session="$(node_session "$label")"
  log_file="$(node_log_file "$label")"
  pid_file="$(node_pid_file "$label")"

  EXPANSO_EDGE_DATA_DIR="$data_dir" \
  EXPANSO_EDGE_TMUX_SESSION="$session" \
  EXPANSO_EDGE_LOG="$log_file" \
  EXPANSO_EDGE_PID="$pid_file" \
    "$RUN_LOCAL" --stop-background
}

status_node() {
  local index="$1"
  local label data_dir session log_file pid_file port state pid node_id

  label="$(node_label "$index")"
  data_dir="$(node_data_dir "$label")"
  session="$(node_session "$label")"
  log_file="$(node_log_file "$label")"
  pid_file="$(node_pid_file "$label")"
  port=$((BASE_PORT + index))
  state="stopped"
  pid="-"
  node_id="-"

  if command -v tmux >/dev/null 2>&1 && tmux has-session -t "$session" 2>/dev/null; then
    state="running"
  fi

  if [[ -f "$pid_file" ]]; then
    pid="$(cat "$pid_file")"
    if ! ps -p "$pid" >/dev/null 2>&1; then
      pid="$pid?"
    fi
  fi

  if [[ -f "$log_file" ]]; then
    node_id="$(tr '\r' '\n' < "$log_file" | grep -E 'node_id=|nodeID=' | tail -n 1 | sed -E 's/.*(node_id|nodeID)=([^ ]+).*/\2/' || true)"
    if [[ -z "$node_id" ]]; then
      node_id="-"
    fi
  fi

  printf "%-5s %-8s %-8s %-16s %-40s %s\n" "$label" "$state" "$pid" "localhost:$port" "$node_id" "$data_dir"
}

case "$MODE" in
  start)
    for ((i = 1; i <= COUNT; i++)); do
      start_node "$i"
    done
    ;;
  stop)
    for ((i = 1; i <= COUNT; i++)); do
      stop_node "$i"
    done
    ;;
  status)
    printf "%-5s %-8s %-8s %-16s %-40s %s\n" "NODE" "STATE" "PID" "API" "NODE_ID" "DATA_DIR"
    for ((i = 1; i <= COUNT; i++)); do
      status_node "$i"
    done
    ;;
esac
