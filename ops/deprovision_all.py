#!/usr/bin/env python3
"""Deprovision all backends from IOTA."""
import os
import sys

import requests
import yaml

ROOT = os.path.join(os.path.dirname(__file__), "..")
CONFIG_PATH = os.path.join(ROOT, "config", "config.yaml")


def main():
    if not os.path.isfile(CONFIG_PATH):
        print(f"Error: {CONFIG_PATH} not found.", file=sys.stderr)
        sys.exit(1)

    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    iota_host = cfg.get("iota_host", "localhost")
    iota_port = cfg.get("iota_north_port", "4041")
    fiware_service = cfg.get("fiware_service", "lqs_iot")
    fiware_path = cfg.get("fiware_servicepath", "/")

    headers = {
        "fiware-service": fiware_service,
        "fiware-servicepath": fiware_path,
    }

    backends = cfg.get("backends") or []
    for i, backend in enumerate(backends):
        device_id = backend.get("device_id", f"backend{i}")
        url = f"http://{iota_host}:{iota_port}/iot/devices/{device_id}"

        print(f"Deprovisioning {device_id}...")
        try:
            r = requests.delete(url, headers=headers, timeout=10)
            print(f"  HTTP {r.status_code}")
        except Exception as e:
            print(f"  Error: {e}", file=sys.stderr)

    print("Done. To remove Orion entities, run LQS-IoT_Pylon/debug/delete_entity.sh")


if __name__ == "__main__":
    main()
