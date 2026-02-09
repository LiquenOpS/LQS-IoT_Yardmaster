#!/usr/bin/env bash
# Register this device to Discovery so it can be adopted from Odoo (Manual Step 1 + Adopt Step 2).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/config/config.env" ] && CONFIG_DIR="$ROOT/config" || CONFIG_DIR="$ROOT"
set -a
source "$CONFIG_DIR/config.env"
[ -f "$CONFIG_DIR/device.env" ] && source "$CONFIG_DIR/device.env"
set +a

if [ -z "${DEVICE_ID:-}" ] || [ -z "${DEVICE_NAME:-}" ]; then
  echo "Error: DEVICE_ID or DEVICE_NAME not set. Run setup.sh Install essentials first." >&2
  exit 1
fi

DISCOVERY_HOST="${DISCOVERY_HOST:-localhost}"
DISCOVERY_PORT="${DISCOVERY_PORT:-5050}"
ENDPOINT="http://${YARDMASTER_HOST}:${YARDMASTER_PORT}/command"
DISCOVERY_URL="http://${DISCOVERY_HOST}:${DISCOVERY_PORT}/devices"

echo "Registering ${DEVICE_ID} (${DEVICE_NAME}) to Discovery..."
curl -sS -X POST "$DISCOVERY_URL" \
  -H "Content-Type: application/json" \
  -d "{\"device_id\":\"${DEVICE_ID}\",\"device_name\":\"${DEVICE_NAME}\",\"endpoint\":\"${ENDPOINT}\"}"
echo ""
echo "Done. Device is now pending in Discovery. Use Adopt in Odoo Fleet to provision."
