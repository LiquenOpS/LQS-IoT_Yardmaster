#!/bin/bash
# Manual heartbeat (gateway sends in-process every 2 min; use this for testing.)
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

# Heartbeat sends deviceStatus only. Static attrs (supportedType, supportedEffects) are sent once at Yardmaster startup.
PAYLOAD='{"deviceStatus":"online"}'

HTTP_CODE=$(curl -s -o /tmp/send_heartbeat_resp -w "%{http_code}" -X POST \
  "http://${IOTA_HOST}:${IOTA_SOUTH_PORT}/iot/json?k=${API_KEY}&i=${DEVICE_ID}" \
  -H "${HEADER_CONTENT_TYPE}" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}" \
  --data-raw "$PAYLOAD")
if [[ "$HTTP_CODE" =~ ^(200|204)$ ]]; then
  echo "OK (HTTP $HTTP_CODE)"
else
  echo "Failed (HTTP $HTTP_CODE): $(cat /tmp/send_heartbeat_resp 2>/dev/null)"
  exit 1
fi
