#!/bin/bash

# Usage: provision_device.sh [--from-discovery] [--endpoint URL]
#   --from-discovery: fetch endpoint from Discovery API by DEVICE_ID
#   --endpoint URL:   override endpoint (e.g. from Discovery or manual)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/config/config.env" ] && CONFIG_DIR="$ROOT/config" || CONFIG_DIR="$ROOT"
set -a
source "$CONFIG_DIR/config.env"
[ -f "$CONFIG_DIR/device.env" ] && source "$CONFIG_DIR/device.env"
set +a

PROVISION_ENDPOINT=""
PROVISION_FROM_DISCOVERY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-discovery) PROVISION_FROM_DISCOVERY=1; shift ;;
    --endpoint)       PROVISION_ENDPOINT="$2"; shift 2 ;;
    *) break ;;
  esac
done
if [ -z "$DEVICE_ID" ] || [ -z "$DEVICE_NAME" ]; then
  echo "Error: DEVICE_ID or DEVICE_NAME not set."
  exit 1
fi

# supportedType: Signage, LED-strip, or Signage,LED-strip
SUPPORTED_TYPE=""
[ "$ENABLE_SIGNAGE" = "true" ] && SUPPORTED_TYPE="Signage"
[ "$ENABLE_LED_STRIP" = "true" ] && {
  [ -n "$SUPPORTED_TYPE" ] && SUPPORTED_TYPE="${SUPPORTED_TYPE},LED-strip" || SUPPORTED_TYPE="LED-strip"
}

# Build commands array
CMD_PARTS=""
if [ "$ENABLE_SIGNAGE" = "true" ]; then
  CMD_PARTS='{"name":"listAssets","type":"command"},{"name":"createAsset","type":"command"},{"name":"deleteAsset","type":"command"},{"name":"updatePlaylistOrder","type":"command"},{"name":"updateAssetPatch","type":"command"}'
fi
if [ "$ENABLE_LED_STRIP" = "true" ]; then
  LED_CMDS='{"name":"ledConfig","type":"command"},{"name":"effectSet","type":"command"},{"name":"playlistResume","type":"command"},{"name":"playlistAdd","type":"command"},{"name":"playlistRemove","type":"command"}'
  [ -n "$CMD_PARTS" ] && CMD_PARTS="${CMD_PARTS},${LED_CMDS}" || CMD_PARTS="${LED_CMDS}"
fi

# Build attributes array (camelCase)
ATTR_PARTS='{"object_id":"deviceStatus","name":"deviceStatus","type":"Text"},{"object_id":"supportedType","name":"supportedType","type":"Text"}'
[ "$ENABLE_SIGNAGE" = "true" ] && ATTR_PARTS="${ATTR_PARTS},{\"object_id\":\"displayUrl\",\"name\":\"displayUrl\",\"type\":\"Text\"}"

# Resolve endpoint: --endpoint > --from-discovery > config
ENDPOINT=""
if [ -n "${PROVISION_ENDPOINT:-}" ]; then
  ENDPOINT="$PROVISION_ENDPOINT"
elif [ -n "${PROVISION_FROM_DISCOVERY:-}" ]; then
  DISCOVERY_HOST="${DISCOVERY_HOST:-localhost}"
  DISCOVERY_PORT="${DISCOVERY_PORT:-5050}"
  DISCOVERY_URL="http://${DISCOVERY_HOST}:${DISCOVERY_PORT}/devices/${DEVICE_ID}"
  RESP=$(curl -sS -f "$DISCOVERY_URL" 2>/dev/null) || { echo "Error: could not fetch from Discovery ($DISCOVERY_URL)" >&2; exit 1; }
  ENDPOINT=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('endpoint',''))")
  [ -z "$ENDPOINT" ] && { echo "Error: no endpoint in Discovery for ${DEVICE_ID}" >&2; exit 1; }
else
  ENDPOINT="http://${YARDMASTER_HOST}:${YARDMASTER_PORT}/command"
fi

PAYLOAD=$(cat <<EOF
{
  "devices": [
    {
      "device_id": "${DEVICE_ID}",
      "entity_name": "${DEVICE_NAME}",
      "entity_type": "Yardmaster",
      "transport": "HTTP",
      "protocol": "PDI-IoTA-JSON",
      "apikey": "${API_KEY}",
      "endpoint": "${ENDPOINT}",
      "commands": [ ${CMD_PARTS} ],
      "attributes": [ ${ATTR_PARTS} ]
    }
  ]
}
EOF
)

echo "Provisioning Yardmaster device: ${DEVICE_ID} ${DEVICE_NAME} (supportedType=${SUPPORTED_TYPE})"
echo "----------------------------------------------"

curl -iX POST "http://${IOTA_HOST}:${IOTA_NORTH_PORT}/iot/devices" \
  -H "Content-Type: application/json" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}" \
  --data-raw "${PAYLOAD}"

echo -e "\nDone. If status code 200/201, device was provisioned."
