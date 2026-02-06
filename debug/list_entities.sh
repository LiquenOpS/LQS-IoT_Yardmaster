#!/bin/bash
ROOT="$(dirname "$(readlink -f "$0")")/.."
[ -f "$ROOT/config/config.env" ] && CONFIG_DIR="$ROOT/config" || CONFIG_DIR="$ROOT"
set -a
source "$CONFIG_DIR/config.env"
set +a
echo "Entities (Orion) for ${FIWARE_SERVICE}..."
curl -s -L -X GET "http://${ORION_HOST}:${ORION_PORT}/v2/entities" \
  -H "${HEADER_FIWARE_SERVICE}" \
  -H "${HEADER_FIWARE_SERVICEPATH}" | jq .
