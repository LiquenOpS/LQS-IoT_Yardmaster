# LQS-IoT Yardmaster

Single FIWARE device (entity type **Yardmaster**) that can expose **Signage** (anthias) and/or **LEDStrip** (Glimmer) capabilities. One endpoint, one entity, attributes in camelCase (`deviceStatus`, `supportedType`, `displayUrl`).

## Setup

1. Run `./setup.sh` once. It will:
   - Create `venv`, install deps from `requirements.txt` (Python 3.10+).
   - Create `config/` from `config.example` if missing (gitignored);
   - Prompt for Device ID / Device Name (defaults: yardmaster-01, Yardmaster-01).
   - On first run: prompt Enable Signage? / Enable LEDStrip? and write to config.
   - Ask whether to edit `config/config.env` for IOTA host, URLs, etc. (optional).
   - Provision the device with FIWARE. Heartbeat (deviceStatus) is sent by the gateway service every 2 min.
2. Start the command gateway:
   - **As service (recommended):** In setup choose "Install systemd service", or manually:
     `sed 's|@INSTALL_DIR@|/path/to/LQS-IoT_Yardmaster|' ops/systemd/yardmaster.service | sudo tee /etc/systemd/system/yardmaster.service`
     then `sudo systemctl daemon-reload && sudo systemctl enable --now yardmaster`
   - **Manual:** `./run.sh` (sources config and starts Flask).  
   Health: `GET /health`.

## FIWARE

- **Entity type:** `Yardmaster`
- **Attributes:** `deviceStatus`, `supportedType`, `displayUrl` (when Signage enabled)
- **Commands:** Signage — `listAssets`, `createAsset`, `deleteAsset`, `updatePlaylistOrder`, `updateAssetPatch`. LEDStrip — `ledConfig`, `effectSet`, `playlistResume`, `playlistAdd`, `playlistRemove` (Glimmer v2026-02-05 API).

## Glimmer (LEDStrip)

- `ledConfig` → `POST {GLIMMER_BASE_URL}/api/config` (new config structure: `runtime.effects_playlist`, `effects.rainbow`, etc.)
- `effectSet` → `POST /api/effect/set`
- `playlistResume` / `playlistAdd` / `playlistRemove` → same paths on Glimmer

## Debug

- `debug/list_devices.sh` — IOTA devices
- `debug/list_entities.sh` — Orion entities (needs `ORION_HOST`, `ORION_PORT` in config)
- `debug/list_group.sh` — IOTA service groups
- `debug/send_heartbeat.sh` — manual heartbeat (for testing; gateway sends in-process)
