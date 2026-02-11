#!/bin/bash
# Deprovision this Yardmaster device from IOTA. Reads from config (IOTA_HOST, etc.).
# Also removes the entity from Orion if ORION_HOST/ORION_PORT are set.

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

# 2. Delete entity from Orion (optional; IOTA may not auto-remove)
ORION_HOST="${ORION_HOST:-}"
ORION_PORT="${ORION_PORT:-1026}"
if [ -n "$ORION_HOST" ]; then
  echo "Deleting Orion entity: ${DEVICE_NAME}"
  curl -i -X DELETE "http://${ORION_HOST}:${ORION_PORT}/v2/entities/${DEVICE_NAME}" \
    -H "Fiware-Service: ${FIWARE_SERVICE}" \
    -H "Fiware-Servicepath: ${FIWARE_SERVICEPATH}"
  echo ""
fi

echo "Done. If status 204, device was removed. Re-provision with setup.sh option 2 to re-test."
