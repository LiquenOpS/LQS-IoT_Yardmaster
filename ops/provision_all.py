#!/usr/bin/env python3
"""Provision all backends from config.yaml to IOTA."""
import json
import os
import sys

import requests
import yaml

ROOT = os.path.join(os.path.dirname(__file__), "..")
CONFIG_PATH = os.path.join(ROOT, "config", "config.yaml")

ENTITY_TYPE = {"Glimmer": "LEDStrip", "Anthias": "Signage"}

SIGNAGE_CMDS = [
    {"name": "listAssets", "type": "command"},
    {"name": "createAsset", "type": "command"},
    {"name": "deleteAsset", "type": "command"},
    {"name": "updatePlaylistOrder", "type": "command"},
    {"name": "updateAssetPatch", "type": "command"},
]
LEDSTRIP_CMDS = [
    {"name": "ledConfig", "type": "command"},
    {"name": "effectSet", "type": "command"},
    {"name": "playlistResume", "type": "command"},
    {"name": "playlistAdd", "type": "command"},
    {"name": "playlistRemove", "type": "command"},
]
CMDS_BY_TYPE = {
    "Glimmer": LEDSTRIP_CMDS + [{"name": "setAdopted", "type": "command"}],
    "Anthias": SIGNAGE_CMDS + [{"name": "setAdopted", "type": "command"}],
}

ATTRS_BASE = [
    {"object_id": "deviceStatus", "name": "deviceStatus", "type": "Text"},
    {"object_id": "adopted", "name": "adopted", "type": "Text"},
]
ATTRS_BY_TYPE = {
    "Glimmer": ATTRS_BASE + [{"object_id": "supportedEffects", "name": "supportedEffects", "type": "Text"}],
    "Anthias": ATTRS_BASE + [{"object_id": "displayUrl", "name": "displayUrl", "type": "Text"}],
}


def main():
    if not os.path.isfile(CONFIG_PATH):
        print(f"Error: {CONFIG_PATH} not found.", file=sys.stderr)
        sys.exit(1)

    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    iota_host = cfg.get("iota_host", "localhost")
    iota_port = cfg.get("iota_north_port", "4041")
    api_key = cfg.get("api_key", "YardmasterKey")
    yardmaster_host = cfg.get("edge_device_ip", "localhost")
    fiware_service = cfg.get("fiware_service", "lqs_iot")
    fiware_path = cfg.get("fiware_servicepath", "/")

    url = f"http://{iota_host}:{iota_port}/iot/devices"
    headers = {
        "Content-Type": "application/json",
        "fiware-service": fiware_service,
        "fiware-servicepath": fiware_path,
    }

    backends = cfg.get("backends") or []
    for i, backend in enumerate(backends):
        device_id = backend.get("device_id") or backend.get("device_name") or f"backend{i}"
        device_name = backend.get("device_name") or device_id
        port = backend.get("port", 44011 + i)
        btype = backend.get("type", "Glimmer")
        entity_type = ENTITY_TYPE.get(btype, "LEDStrip")

        endpoint = f"http://{yardmaster_host}:{port}/command"
        commands = CMDS_BY_TYPE.get(btype, CMDS_BY_TYPE["Glimmer"])
        attributes = ATTRS_BY_TYPE.get(btype, ATTRS_BY_TYPE["Glimmer"])

        payload = {
            "devices": [
                {
                    "device_id": device_id,
                    "entity_name": device_name,
                    "entity_type": entity_type,
                    "transport": "HTTP",
                    "protocol": "HTTP",
                    "apikey": api_key,
                    "endpoint": endpoint,
                    "commands": commands,
                    "attributes": attributes,
                }
            ]
        }

        print(f"Provisioning {device_id} ({entity_type}) on port {port}...")
        try:
            r = requests.post(url, headers=headers, json=payload, timeout=10)
            print(f"  HTTP {r.status_code}")
            if r.status_code not in (200, 201):
                print(f"  Response: {r.text[:500]}", file=sys.stderr)
        except Exception as e:
            print(f"  Error: {e}", file=sys.stderr)
            sys.exit(1)

    print("Done.")


if __name__ == "__main__":
    main()
