#!/bin/bash
# Entrypoint: loads config.yaml, spawns Waitress per backend.

set -e
ROOT="$(dirname "$(readlink -f "$0")")"
cd "$ROOT"

if [ ! -f "$ROOT/config/config.yaml" ]; then
  echo "Error: config/config.yaml not found. Run ./setup.sh first." >&2
  exit 1
fi

PYTHON="${ROOT}/venv/bin/python3"
if [ ! -x "$PYTHON" ]; then
  echo "Error: venv not found. Run ./setup.sh first." >&2
  exit 1
fi
export PYTHONPATH="$ROOT"
exec "$PYTHON" -m gateway.app
