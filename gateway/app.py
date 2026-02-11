from flask import Flask, request, jsonify
import requests
import json
import os
import logging
import threading
import time

from dotenv import load_dotenv

log = logging.getLogger(__name__)
_root = os.path.join(os.path.dirname(__file__), "..")
_config_dir = os.path.join(_root, "config")
if os.path.isfile(os.path.join(_config_dir, "config.env")):
    load_dotenv(os.path.join(_config_dir, "config.env"))
    load_dotenv(os.path.join(_config_dir, "device.env"))
else:
    load_dotenv(os.path.join(_root, "config.env"))
    load_dotenv(os.path.join(_root, "device.env"))

app = Flask(__name__)

IOTA_HOST = os.environ.get("IOTA_HOST", "localhost")
LOG_LEVEL = getattr(logging, os.environ.get("LOG_LEVEL", "INFO").upper(), logging.INFO)
IOTA_SOUTH_PORT = os.environ.get("IOTA_SOUTH_PORT", "7896")
API_KEY = os.environ.get("API_KEY", "YardmasterKey")
ENTITY_ID = os.environ.get("DEVICE_ID")
ANTHIAS_BASE_URL = os.environ.get("ANTHIAS_BASE_URL", "http://localhost:8000/api/v2/assets")
GLIMMER_BASE_URL = os.environ.get("GLIMMER_BASE_URL", "http://localhost:1129").rstrip("/")
ENABLE_SIGNAGE = os.environ.get("ENABLE_SIGNAGE", "true").lower() == "true"
ENABLE_LED_STRIP = os.environ.get("ENABLE_LED_STRIP", "true").lower() == "true"

logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s %(levelname)s %(message)s")

NORTHBOUND_URL = f"http://{IOTA_HOST}:{IOTA_SOUTH_PORT}/iot/json"
HEARTBEAT_INTERVAL = 120  # seconds
FIWARE_SERVICE = os.environ.get("FIWARE_SERVICE", "lqs_iot")
FIWARE_SERVICEPATH = os.environ.get("FIWARE_SERVICEPATH", "/")

_IOTA_HEADERS = {
    "Content-Type": "application/json",
    "Fiware-Service": FIWARE_SERVICE,
    "Fiware-Servicepath": FIWARE_SERVICEPATH,
}


def _build_supported_type():
    parts = []
    if ENABLE_SIGNAGE:
        parts.append("Signage")
    if ENABLE_LED_STRIP:
        parts.append("LEDStrip")
    return ",".join(parts) or ""


def _heartbeat_loop():
    """Send deviceStatus + supportedType to IOTA South every HEARTBEAT_INTERVAL (service runs in process)."""
    time.sleep(10)  # let server bind first
    supported_type = _build_supported_type()
    while True:
        try:
            payload = {"deviceStatus": "online"}
            if supported_type:
                payload["supportedType"] = supported_type
            requests.post(
                NORTHBOUND_URL,
                params={"k": API_KEY, "i": ENTITY_ID},
                json=payload,
                headers=_IOTA_HEADERS,
                timeout=10,
            )
            log.debug("Heartbeat sent: %s", payload)
        except Exception as e:
            log.error("Heartbeat error: %s", e)
        time.sleep(HEARTBEAT_INTERVAL)


def send_northbound_response(resp_data):
    params = {"k": API_KEY, "i": ENTITY_ID}
    try:
        r = requests.post(NORTHBOUND_URL, params=params, headers=_IOTA_HEADERS, data=json.dumps(resp_data), timeout=10)
        r.raise_for_status()
        return r.json()
    except requests.RequestException as e:
        print(f"Northbound error: {e}")
        return {"error": str(e)}


# ----- Signage (anthias) -----
def list_assets(data):
    r = requests.get(f"{ANTHIAS_BASE_URL}/", headers={"Content-Type": "application/json"}, timeout=10)
    return r.json()

def create_asset(data):
    asset = data.get("createAsset", {})
    asset["skip_asset_check"] = False
    r = requests.post(f"{ANTHIAS_BASE_URL}", json=asset, headers={"Content-Type": "application/json"}, timeout=10)
    return r.json()

def update_asset_patch(data):
    asset = data.get("updateAssetPatch", {})
    asset_id = asset.get("asset_id")
    r = requests.patch(f"{ANTHIAS_BASE_URL}/{asset_id}", json=asset, headers={"Content-Type": "application/json"}, timeout=10)
    return r.json()

def delete_asset(data):
    payload = data.get("deleteAsset", {})
    asset_id = payload.get("asset_id")
    r = requests.delete(f"{ANTHIAS_BASE_URL}/{asset_id}", headers={"Content-Type": "application/json"}, timeout=10)
    if r.status_code == 204:
        return {"status": "success", "asset_id": asset_id, "message": "Deleted successfully."}
    return r.json() if r.content else {}

def update_playlist_order(data):
    r = requests.post(f"{ANTHIAS_BASE_URL}/order", json=data.get("updatePlaylistOrder", {}), headers={"Content-Type": "application/json"}, timeout=10)
    if r.status_code == 204:
        return {"status": "success", "message": "Updated successfully."}
    return r.json() if r.content else {}


# ----- LEDStrip (Glimmer v2026-02-05) -----
def glimmer_post(path, body=None):
    url = f"{GLIMMER_BASE_URL}{path}"
    r = requests.post(url, json=body or {}, headers={"Content-Type": "application/json"}, timeout=10)
    try:
        return r.json() if r.content else {}
    except Exception:
        return {"status_code": r.status_code, "text": r.text}


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200


@app.route("/command", methods=["POST"])
def dispatch_command():
    data = request.get_json() or {}
    log.info("Command received: %s", list(data.keys()) if data else "empty")
    result = None

    # Signage
    if data.get("listAssets") is not None:
        if not ENABLE_SIGNAGE:
            return jsonify({"error": "Signage not enabled"}), 501
        result = list_assets(data)
    elif data.get("createAsset") is not None:
        if not ENABLE_SIGNAGE:
            return jsonify({"error": "Signage not enabled"}), 501
        result = create_asset(data)
    elif data.get("updateAssetPatch") is not None:
        if not ENABLE_SIGNAGE:
            return jsonify({"error": "Signage not enabled"}), 501
        result = update_asset_patch(data)
    elif data.get("deleteAsset") is not None:
        if not ENABLE_SIGNAGE:
            return jsonify({"error": "Signage not enabled"}), 501
        result = delete_asset(data)
    elif data.get("updatePlaylistOrder") is not None:
        if not ENABLE_SIGNAGE:
            return jsonify({"error": "Signage not enabled"}), 501
        result = update_playlist_order(data)

    # LEDStrip (Glimmer)
    elif data.get("ledConfig") is not None:
        if not ENABLE_LED_STRIP:
            return jsonify({"error": "LEDStrip not enabled"}), 501
        result = glimmer_post("/api/config", data.get("ledConfig"))
    elif data.get("effectSet") is not None:
        if not ENABLE_LED_STRIP:
            return jsonify({"error": "LEDStrip not enabled"}), 501
        result = glimmer_post("/api/effect/set", data.get("effectSet"))
    elif data.get("playlistResume") is not None:
        if not ENABLE_LED_STRIP:
            return jsonify({"error": "LEDStrip not enabled"}), 501
        result = glimmer_post("/api/playlist/resume")
    elif data.get("playlistAdd") is not None:
        if not ENABLE_LED_STRIP:
            return jsonify({"error": "LEDStrip not enabled"}), 501
        result = glimmer_post("/api/playlist/add", data.get("playlistAdd"))
    elif data.get("playlistRemove") is not None:
        if not ENABLE_LED_STRIP:
            return jsonify({"error": "LEDStrip not enabled"}), 501
        result = glimmer_post("/api/playlist/remove", data.get("playlistRemove"))

    if result is None:
        return jsonify({"error": "Unknown command"}), 400

    send_northbound_response(result)
    log.info("Command dispatched, result keys: %s", list(result.keys()) if isinstance(result, dict) else str(result)[:80])
    return jsonify(result)


# Start heartbeat thread (daemon so it exits with the process)
if ENTITY_ID:
    _hb = threading.Thread(target=_heartbeat_loop, daemon=True)
    _hb.start()
