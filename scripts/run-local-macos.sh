#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOTENV_PATH="${EXPANSO_DOTENV:-$REPO_ROOT/.env}"

if [[ -f "$DOTENV_PATH" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$DOTENV_PATH"
  set +a
fi

EDGE_BIN="${EXPANSO_EDGE_BIN:-/usr/local/bin/expanso-edge}"
DATA_DIR="${EXPANSO_EDGE_DATA_DIR:-$HOME/.expanso/edge}"
CREDS_FILE="$DATA_DIR/auth/credentials.creds"
PID_FILE="${EXPANSO_EDGE_PID:-/tmp/jetpack-expanso/edge.pid}"
LOG_FILE="${EXPANSO_EDGE_LOG:-/tmp/jetpack-expanso/edge.log}"
TMUX_SESSION="${EXPANSO_EDGE_TMUX_SESSION:-jetpack-expanso-edge}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: this helper is for macOS only" >&2
  exit 1
fi

if [[ ! -x "$EDGE_BIN" ]]; then
  echo "error: expanso-edge not found at $EDGE_BIN" >&2
  echo "Install it with the Expanso installer, or set EXPANSO_EDGE_BIN." >&2
  exit 1
fi

require_credentials() {
  if [[ -f "$CREDS_FILE" ]]; then
    return 0
  fi

  echo "error: local edge credentials not found at $CREDS_FILE" >&2
  echo "Bootstrap first with: $0 --bootstrap" >&2
  exit 1
}

echo "Starting expanso-edge from $EDGE_BIN"
echo "Using data directory $DATA_DIR"

if [[ "${1:-}" == "--check" ]]; then
  require_credentials
  echo "Local macOS edge prerequisites OK."
  exit 0
fi

if [[ "${1:-}" == "--bootstrap" ]]; then
  if [[ -z "${EXPANSO_EDGE_BOOTSTRAP_TOKEN:-}" ]]; then
    echo "error: EXPANSO_EDGE_BOOTSTRAP_TOKEN is not set" >&2
    exit 1
  fi

  bootstrap_cmd=("$EDGE_BIN" bootstrap --data-dir "$DATA_DIR" --token "$EXPANSO_EDGE_BOOTSTRAP_TOKEN")
  if [[ -n "${EXPANSO_EDGE_BOOTSTRAP_URL:-}" ]]; then
    bootstrap_cmd+=(--url "$EXPANSO_EDGE_BOOTSTRAP_URL")
  fi

  "${bootstrap_cmd[@]}"
  exit 0
fi

if [[ "${1:-}" == "--stop-background" ]]; then
  if command -v tmux >/dev/null 2>&1 && tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    tmux kill-session -t "$TMUX_SESSION"
    echo "Stopped tmux session $TMUX_SESSION."
  fi
  rm -f "$PID_FILE"
  exit 0
fi

if [[ "${1:-}" == "--background" ]]; then
  require_credentials
  shift
  if ! command -v tmux >/dev/null 2>&1; then
    echo "error: tmux is required for background mode" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$LOG_FILE")"
  mkdir -p "$(dirname "$PID_FILE")"
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true

  tmux_cmd="exec $(printf '%q' "$EDGE_BIN") run --data-dir $(printf '%q' "$DATA_DIR")"
  for arg in "$@"; do
    tmux_cmd="$tmux_cmd $(printf '%q' "$arg")"
  done

  : > "$LOG_FILE"
  tmux new-session -d -s "$TMUX_SESSION" "$tmux_cmd"
  tmux pipe-pane -t "$TMUX_SESSION" -o "cat >> $(printf '%q' "$LOG_FILE")"
  tmux list-panes -t "$TMUX_SESSION" -F "#{pane_pid}" > "$PID_FILE"
  echo "Started tmux session $TMUX_SESSION with expanso-edge PID $(cat "$PID_FILE")."
  echo "Logs: $LOG_FILE"
  exit 0
fi

require_credentials
echo "Logs stay attached to this terminal. Press Ctrl-C to stop."

exec "$EDGE_BIN" run --data-dir "$DATA_DIR" "$@"
