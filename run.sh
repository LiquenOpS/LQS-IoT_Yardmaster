#!/bin/bash
# Entrypoint for Flask app (used by systemd or manual run). Sources config and starts the server.

set -e
ROOT="$(dirname "$(readlink -f "$0")")"
cd "$ROOT"

[ -f "$ROOT/config/config.env" ] && CONFIG_DIR="$ROOT/config" || CONFIG_DIR="$ROOT"
set -a
source "$CONFIG_DIR/config.env"
[ -f "$CONFIG_DIR/device.env" ] && source "$CONFIG_DIR/device.env"
set +a

exec python3 -m flask --app flask.app run --host=0.0.0.0 --port="${YARDMASTER_PORT:-5000}"
