#!/bin/bash
# Deprovision this Yardmaster device from IOTA. Reads from config (IOTA_HOST, etc.).
# To remove the entity from Orion, run LQS-IoT_Pylon/debug/delete_entity.sh on the Pylon host.

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

echo "Deprovisioning Yardmaster device: ${DEVICE_ID} (entity: ${DEVICE_NAME})"
echo "----------------------------------------------"

# 1. Delete from IOTA
curl -i -X DELETE "http://${IOTA_HOST}:${IOTA_NORTH_PORT}/iot/devices/${DEVICE_ID}" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}"
echo ""

echo "Done. If status 204, device was removed from IOTA. Re-provision with setup.sh option 2 to re-test."
echo "To also remove the entity from Orion, run: LQS-IoT_Pylon/debug/delete_entity.sh"
