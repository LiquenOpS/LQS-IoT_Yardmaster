#!/bin/bash
# Entrypoint for Flask app (used by systemd or manual run). Sources config and starts the server.

set -e
ROOT="$(dirname "$(readlink -f "$0")")"
cd "$ROOT"

if [ ! -f "$ROOT/config/config.env" ]; then
  echo "Error: config/config.env not found. Run ./setup.sh first." >&2
  exit 1
fi
CONFIG_DIR="$ROOT/config"
set -a
source "$CONFIG_DIR/config.env"
[ -f "$CONFIG_DIR/device.env" ] && source "$CONFIG_DIR/device.env"
set +a

PYTHON="${ROOT}/.venv/bin/python3"
if [ ! -x "$PYTHON" ]; then
  echo "Error: .venv not found. Run ./setup.sh first." >&2
  exit 1
fi
export PYTHONPATH="$ROOT"
exec "$PYTHON" -m flask --app "gateway.app:app" run --host=0.0.0.0 --port="${YARDMASTER_PORT:-8080}"
