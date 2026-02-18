"""
Yardmaster multi-backend gateway.
Each backend runs on its own port. Main entry spawns Waitress threads.
"""
import base64
import json
import logging
import os
import threading
import time

import requests
import yaml
from flask import Flask, request, jsonify
from waitress import serve

_ROOT = os.path.join(os.path.dirname(__file__), "..")
_CONFIG_DIR = os.path.join(_ROOT, "config")
_HEARTBEAT_INTERVAL = 120
_RETRY_INTERVAL = 30


def _encode_b64_payload(obj):
    """Per COMMAND_RESPONSE_SPEC: base64url encode JSON for Orion-forbidden chars."""
    raw = json.dumps(obj, ensure_ascii=False)
    b64 = base64.urlsafe_b64encode(raw.encode("utf-8")).decode("ascii").rstrip("=")
    return f"b64:{b64}"


def load_config():
    """Load config from config/config.yaml. Raises if missing."""
    path = os.path.join(_CONFIG_DIR, "config.yaml")
    if not os.path.isfile(path):
        raise FileNotFoundError(f"Config not found: {path}. Run setup.sh first.")
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def create_backend_app(backend_cfg, common_cfg, backend_index):
    """Create Flask app for one backend. Each has own adopt state, heartbeat, handlers."""
    app = Flask(__name__)
    log = logging.getLogger(f"yardmaster.backend{backend_index}")

    # Backend config
    backend_type = backend_cfg.get("type", "").strip()
    is_signage = backend_type.lower() == "anthias"
    is_ledstrip = backend_type.lower() == "glimmer"
    entity_id = backend_cfg.get("device_id", "")
    base_url = (backend_cfg.get("base_url", "") or "").rstrip("/")
    port = backend_cfg.get("port", 44011)

    # Common config
    iota_host = common_cfg.get("iota_host", "localhost")
    iota_south = common_cfg.get("iota_south_port", "7896")
    api_key = common_cfg.get("api_key", "YardmasterKey")
    fiware_svc = common_cfg.get("fiware_service", "lqs_iot")
    fiware_path = common_cfg.get("fiware_servicepath", "/")

    northbound_url = f"http://{iota_host}:{iota_south}/iot/json"
    adopt_file = os.path.join(_CONFIG_DIR, f"adopt_backend_{backend_index}.json")
    iota_headers = {
        "Content-Type": "application/json",
        "Fiware-Service": fiware_svc,
        "Fiware-Servicepath": fiware_path,
    }

    def load_adopted():
        try:
            if os.path.isfile(adopt_file):
                with open(adopt_file, "r", encoding="utf-8") as f:
                    return bool(json.load(f).get("adopted", False))
        except Exception as e:
            log.warning("Could not load adopt state: %s", e)
        return False

    def save_adopted(adopted):
        try:
            os.makedirs(os.path.dirname(adopt_file), exist_ok=True)
            with open(adopt_file, "w", encoding="utf-8") as f:
                json.dump({"adopted": adopted}, f, indent=2)
        except Exception as e:
            log.error("Could not save adopt state: %s", e)

    adopted_ref = {"value": load_adopted()}

    def fetch_glimmer_effects():
        if not is_ledstrip or not base_url:
            return None
        try:
            r = requests.get(
                f"{base_url}/api/config",
                headers={"Content-Type": "application/json"},
                timeout=5,
            )
            r.raise_for_status()
            data = r.json()
            effects = data.get("hardware", {}).get("supported_effects")
            if isinstance(effects, list) and effects:
                return ",".join(str(e) for e in effects)
        except Exception as e:
            log.warning("Could not fetch Glimmer supported_effects: %s", e)
        return None

    def heartbeat_loop():
        time.sleep(10)
        while True:
            try:
                if adopted_ref["value"]:
                    payload = {"deviceStatus": "online", "adopted": True}
                    if is_ledstrip:
                        effects = fetch_glimmer_effects()
                        if effects:
                            payload["supportedEffects"] = effects
                    interval = _HEARTBEAT_INTERVAL
                else:
                    payload = {"deviceStatus": "online", "adopted": False}
                    interval = _RETRY_INTERVAL
                requests.post(
                    northbound_url,
                    params={"k": api_key, "i": entity_id},
                    json=payload,
                    headers=iota_headers,
                    timeout=10,
                )
            except Exception as e:
                log.error("Heartbeat error: %s", e)
            time.sleep(interval)

    def anthias_resp(r):
        try:
            body = r.json() if r.content else {}
        except Exception:
            body = {}
        if r.ok:
            return body
        detail = body.get("detail") or body.get("message") or body.get("error") or r.text[:200] or f"HTTP {r.status_code}"
        return {"status": "error", "detail": str(detail), "http_status": r.status_code}

    def glimmer_post(path, body=None):
        url = f"{base_url}{path}"
        r = requests.post(url, json=body or {}, headers={"Content-Type": "application/json"}, timeout=10)
        try:
            return r.json() if r.content else {}
        except Exception:
            return {"status_code": r.status_code, "text": r.text}

    @app.route("/health", methods=["GET"])
    def health():
        return jsonify({"status": "ok", "backend": backend_index}), 200

    def command_name_from_data(data):
        for k in ("createAsset", "deleteAsset", "updateAssetPatch", "updatePlaylistOrder",
                  "listAssets", "setAdopted", "ledConfig", "effectSet", "playlistResume",
                  "playlistAdd", "playlistRemove"):
            if data.get(k) is not None:
                return k
        return None

    @app.route("/command", methods=["POST"])
    def dispatch_command():
        data = request.get_json() or {}
        log.info("Command received: %s", list(data.keys()) if data else "empty")
        result = None

        # setAdopted
        if data.get("setAdopted") is not None:
            cmd = data.get("setAdopted")
            val = cmd.get("value") if isinstance(cmd, dict) else cmd
            adopted = str(val).lower() in ("true", "1", "yes")
            adopted_ref["value"] = adopted
            save_adopted(adopted)
            log.info("setAdopted: %s (persisted)", adopted)
            if adopted and is_ledstrip:
                effects = fetch_glimmer_effects()
                payload = {"deviceStatus": "online", "adopted": True}
                if effects:
                    payload["supportedEffects"] = effects
                try:
                    requests.post(northbound_url, params={"k": api_key, "i": entity_id},
                                 json=payload, headers=iota_headers, timeout=10)
                except Exception as e:
                    log.warning("Could not send type attrs: %s", e)
            elif not adopted:
                try:
                    requests.post(northbound_url, params={"k": api_key, "i": entity_id},
                                 json={"deviceStatus": "online", "adopted": False},
                                 headers=iota_headers, timeout=10)
                except Exception as e:
                    log.warning("Could not send unadopted state: %s", e)
            result = {"status": "ok", "adopted": adopted}

        # Signage (Anthias)
        elif data.get("listAssets") is not None:
            if not is_signage:
                return jsonify({"error": "Signage not enabled"}), 501
            try:
                r = requests.get(base_url, headers={"Content-Type": "application/json"}, timeout=10)
                result = anthias_resp(r)
            except requests.RequestException as e:
                result = {"status": "error", "detail": str(e)}
        elif data.get("createAsset") is not None:
            if not is_signage:
                return jsonify({"error": "Signage not enabled"}), 501
            try:
                raw = data.get("createAsset", {})
                asset = raw.get("value", raw) if isinstance(raw, dict) else {}
                asset = dict(asset) if isinstance(asset, dict) else {}
                asset["skip_asset_check"] = False
                r = requests.post(base_url, json=asset, headers={"Content-Type": "application/json"}, timeout=10)
                out = anthias_resp(r)
                if r.ok and isinstance(out, dict) and "asset_id" not in out and "id" in out:
                    out["asset_id"] = out["id"]
                result = out
            except requests.RequestException as e:
                result = {"status": "error", "detail": str(e)}
        elif data.get("updateAssetPatch") is not None:
            if not is_signage:
                return jsonify({"error": "Signage not enabled"}), 501
            try:
                raw = data.get("updateAssetPatch", {})
                asset = raw.get("value", raw) if isinstance(raw, dict) else {}
                asset_id = asset.get("asset_id")
                if not asset_id:
                    result = {"status": "error", "detail": "asset_id is required"}
                else:
                    r = requests.patch(f"{base_url}/{asset_id}", json=asset,
                                      headers={"Content-Type": "application/json"}, timeout=10)
                    result = {"status": "success", "asset_id": asset_id} if r.status_code == 204 else anthias_resp(r)
            except requests.RequestException as e:
                result = {"status": "error", "detail": str(e)}
        elif data.get("deleteAsset") is not None:
            if not is_signage:
                return jsonify({"error": "Signage not enabled"}), 501
            try:
                raw = data.get("deleteAsset", {})
                payload = raw.get("value", raw) if isinstance(raw, dict) else {}
                asset_id = payload.get("asset_id") if isinstance(payload, dict) else None
                r = requests.delete(f"{base_url}/{asset_id}", headers={"Content-Type": "application/json"}, timeout=10)
                result = {"status": "success", "asset_id": asset_id} if r.status_code == 204 else anthias_resp(r)
            except requests.RequestException as e:
                result = {"status": "error", "detail": str(e)}
        elif data.get("updatePlaylistOrder") is not None:
            if not is_signage:
                return jsonify({"error": "Signage not enabled"}), 501
            try:
                raw = data.get("updatePlaylistOrder", {})
                payload = raw.get("value", raw) if isinstance(raw, dict) else raw or {}
                r = requests.post(f"{base_url}/order", json=payload,
                                 headers={"Content-Type": "application/json"}, timeout=10)
                result = {"status": "success"} if r.status_code == 204 else anthias_resp(r)
            except requests.RequestException as e:
                result = {"status": "error", "detail": str(e)}

        # LEDStrip (Glimmer)
        elif data.get("ledConfig") is not None:
            if not is_ledstrip:
                return jsonify({"error": "LEDStrip not enabled"}), 501
            result = glimmer_post("/api/config", data.get("ledConfig"))
        elif data.get("effectSet") is not None:
            if not is_ledstrip:
                return jsonify({"error": "LEDStrip not enabled"}), 501
            result = glimmer_post("/api/effect/set", data.get("effectSet"))
        elif data.get("playlistResume") is not None:
            if not is_ledstrip:
                return jsonify({"error": "LEDStrip not enabled"}), 501
            result = glimmer_post("/api/playlist/resume")
        elif data.get("playlistAdd") is not None:
            if not is_ledstrip:
                return jsonify({"error": "LEDStrip not enabled"}), 501
            result = glimmer_post("/api/playlist/add", data.get("playlistAdd"))
        elif data.get("playlistRemove") is not None:
            if not is_ledstrip:
                return jsonify({"error": "LEDStrip not enabled"}), 501
            result = glimmer_post("/api/playlist/remove", data.get("playlistRemove"))

        if result is None:
            return jsonify({"error": "Unknown command"}), 400

        cmd_name = command_name_from_data(data)
        resp = dict(result) if isinstance(result, dict) else {}
        payload = result if isinstance(result, list) else resp
        result_str = _encode_b64_payload(payload)
        iota_body = {cmd_name: result_str} if cmd_name and result_str else {}
        log.info("Command result: %s", iota_body)
        return jsonify(iota_body)

    if entity_id:
        t = threading.Thread(target=heartbeat_loop, daemon=True)
        t.start()

    return app


def main():
    """Load config, spawn Waitress thread per backend."""
    cfg = load_config()
    common = {k: cfg.get(k) for k in ("iota_host", "iota_north_port", "iota_south_port",
                                       "api_key", "fiware_service", "fiware_servicepath", "log_level")}
    common.setdefault("iota_host", "localhost")
    common.setdefault("iota_south_port", "7896")
    common.setdefault("api_key", "YardmasterKey")
    common.setdefault("fiware_service", "lqs_iot")
    common.setdefault("fiware_servicepath", "/")

    log_level = getattr(logging, (common.get("log_level") or "INFO").upper(), logging.INFO)
    logging.basicConfig(level=log_level, format="%(asctime)s %(levelname)s %(message)s")
    log = logging.getLogger("yardmaster")

    backends = cfg.get("backends") or []
    if not backends:
        log.error("No backends defined in config.yaml")
        raise SystemExit(1)

    threads = []
    for i, backend in enumerate(backends):
        app = create_backend_app(backend, common, i)
        port = backend.get("port", 44011 + i)
        device_id = backend.get("device_id", f"backend{i}")
        log.info("Starting backend %d: %s on port %d", i, device_id, port)

        def run_server(a, p):
            serve(a, host="0.0.0.0", port=p, threads=1)

        t = threading.Thread(target=run_server, args=(app, port), daemon=True)
        t.start()
        threads.append(t)

    log.info("All %d backends started. Press Ctrl+C to stop.", len(backends))
    try:
        for t in threads:
            t.join()
    except KeyboardInterrupt:
        log.info("Shutting down.")


if __name__ == "__main__":
    main()
