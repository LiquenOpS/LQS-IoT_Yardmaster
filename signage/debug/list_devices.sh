#!/bin/bash
source ../config.env

curl -s -X GET \
	   "http://${IOTA_HOST}:${IOTA_NORTH_PORT}/iot/devices" \
	     -H "Fiware-Service: ${FIWARE_SERVICE}" \
	       -H "Fiware-Servicepath: ${FIWARE_SERVICEPATH}" \
	         | jq .
