#!/bin/bash
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ROOT="$(dirname "$SCRIPT_DIR")"
[ -f "$ROOT/config/config.env" ] && CONFIG_DIR="$ROOT/config" || CONFIG_DIR="$ROOT"
set -a
source "$CONFIG_DIR/config.env"
[ -f "$CONFIG_DIR/device.env" ] && source "$CONFIG_DIR/device.env"
set +a

if [ -z "$DEVICE_ID" ]; then
  echo "Error: DEVICE_ID not set. Run ./setup.sh once."
  exit 1
fi

curl -s -X POST "http://${IOTA_HOST}:${IOTA_SOUTH_PORT}/iot/json?k=${API_KEY}&i=${DEVICE_ID}" \
  -H "${HEADER_CONTENT_TYPE}" \
  --data-raw '{"deviceStatus":"online"}'

echo ""
