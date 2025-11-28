#!/bin/bash

if [ -z "$DEVICE_ID" ] || [ -z "$DEVICE_NAME" ]; then
  echo "Error: DEVICE_ID or DEVICE_NAME not set."
  exit 1
fi

echo "Provisioning IoT Agent with a NeoPixel...: ${DEVICE_ID} ${DEVICE_NAME}"
echo "----------------------------------------------"

PAYLOAD=$(cat <<EOF
{
    "devices": [
        {
            "device_id": "${DEVICE_ID}",
            "entity_name": "${DEVICE_NAME}",
            "entity_type": "NeoPixel",
            "transport": "HTTP",
            "protocol": "PDI-IoTA-JSON",
            "apikey": "SignKeyForNeoPixel",
            "endpoint": "http://${audio_reactive_host}:${audio_reactive_port}/api/config",
            "commands": [
                {
                    "name": "led_config",
                    "type": "command"
                }
            ],
            "attributes": [
                { "object_id": "device_status", "name": "device_status", "type": "Text" }
            ]
        }
    ]
}
EOF
)



curl -iX POST "http://${IOTA_HOST}:${IOTA_NORTH_PORT}/iot/devices" \
-H "Content-Type: application/json" \
-H "${HEADER_FIWARE_SERVICE}" \
-H "${HEADER_FIWARE_SERVICEPATH}" \
--data-raw "${PAYLOAD}"

echo -e "\nDone. If status code is 200, the heartbeat was sent successfully."
