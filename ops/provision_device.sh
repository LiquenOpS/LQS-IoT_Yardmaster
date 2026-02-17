#!/bin/bash
# Provision this Yardmaster device with IOTA. Reads from config (YARDMASTER_HOST, etc.).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/config/config.env" ] && CONFIG_DIR="$ROOT/config" || CONFIG_DIR="$ROOT"
set -a
source "$CONFIG_DIR/config.env"
[ -f "$CONFIG_DIR/device.env" ] && source "$CONFIG_DIR/device.env"
set +a

if [ -z "$DEVICE_ID" ] || [ -z "$DEVICE_NAME" ]; then
  echo "Error: DEVICE_ID or DEVICE_NAME not set."
  exit 1
fi

# supportedType: Signage, LEDStrip, or Signage,LEDStrip
SUPPORTED_TYPE=""
[ "$ENABLE_SIGNAGE" = "true" ] && SUPPORTED_TYPE="Signage"
[ "$ENABLE_LED_STRIP" = "true" ] && {
  [ -n "$SUPPORTED_TYPE" ] && SUPPORTED_TYPE="${SUPPORTED_TYPE},LEDStrip" || SUPPORTED_TYPE="LEDStrip"
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
# setAdopted: Odoo sends on adopt/unadopt; Yardmaster persists and reports adopted attr
[ -n "$CMD_PARTS" ] && CMD_PARTS="${CMD_PARTS},{\"name\":\"setAdopted\",\"type\":\"command\"}" || CMD_PARTS='{"name":"setAdopted","type":"command"}'

# Build attributes array (camelCase). Command result goes in HTTP response body (see FIWARE_COMMAND_RESPONSE.md).
ATTR_PARTS='{"object_id":"deviceStatus","name":"deviceStatus","type":"Text"},{"object_id":"supportedType","name":"supportedType","type":"Text"},{"object_id":"adopted","name":"adopted","type":"Text"}'
[ "$ENABLE_SIGNAGE" = "true" ] && ATTR_PARTS="${ATTR_PARTS},{\"object_id\":\"displayUrl\",\"name\":\"displayUrl\",\"type\":\"Text\"}"
[ "$ENABLE_LED_STRIP" = "true" ] && ATTR_PARTS="${ATTR_PARTS},{\"object_id\":\"supportedEffects\",\"name\":\"supportedEffects\",\"type\":\"Text\"}"

ENDPOINT="http://${YARDMASTER_HOST}:${YARDMASTER_PORT}/command"

PAYLOAD=$(cat <<EOF
{
  "devices": [
    {
      "device_id": "${DEVICE_ID}",
      "entity_name": "${DEVICE_NAME}",
      "entity_type": "Yardmaster",
      "transport": "HTTP",
      "protocol": "HTTP",
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
