#!/bin/bash
ROOT="$(dirname "$(readlink -f "$0")")/.."
[ -f "$ROOT/config/config.env" ] && CONFIG_DIR="$ROOT/config" || CONFIG_DIR="$ROOT"
set -a
source "$CONFIG_DIR/config.env"
set +a
echo "IoT services (service groups) for ${FIWARE_SERVICE}..."
curl -s -L -X GET "http://${IOTA_HOST}:${IOTA_NORTH_PORT}/iot/services" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}" | jq .
