#!/bin/bash
ROOT="$(dirname "$(readlink -f "$0")")/.."
[ -f "$ROOT/config/config.env" ] && CONFIG_DIR="$ROOT/config" || CONFIG_DIR="$ROOT"
set -a
source "$CONFIG_DIR/config.env"
set +a
curl -s -X GET "http://${IOTA_HOST}:${IOTA_NORTH_PORT}/iot/devices" \
  -H "Fiware-Service: ${FIWARE_SERVICE}" \
  -H "Fiware-Servicepath: ${FIWARE_SERVICEPATH}" | jq .
