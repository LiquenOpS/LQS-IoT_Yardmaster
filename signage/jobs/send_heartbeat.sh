#!/bin/bash
# send_heartbeat.sh - Run this periodically via cron job.


SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")

source ${PARENT_DIR}/config.env
source ${PARENT_DIR}/device.env
if [ -z "$DEVICE_ID" ]; then
  echo "Error: DEVICE_ID is not set. Please make sure device.env contains the DEVICE_ID."
  exit 1
fi

curl -s  -X POST "http://${IOTA_HOST}:${IOTA_SOUTH_PORT}/iot/json?k=SignKey&i=${DEVICE_ID}" \
-H "${HEADER_CONTENT_TYPE}" \
--data-raw '{"device_status":"online"}'

echo "Done\n"
