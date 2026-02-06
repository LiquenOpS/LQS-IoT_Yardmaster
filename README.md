# LQS-IoT Yardmaster

Single FIWARE device (entity type **Yardmaster**) that can expose **Signage** (anthias) and/or **LED-strip** (Glimmer) capabilities. One endpoint, one entity, attributes in camelCase (`deviceStatus`, `supportedType`, `displayUrl`).

## Setup

1. `pip install -r requirements.txt` (Python 3.10+).
2. Run `./setup.sh` once. It will:
   - Create `config/` from `config.example` if missing (gitignored).
   - Prompt for Device ID / Device Name (defaults: yardmaster-01, Yardmaster-01).
   - On first run: prompt Enable Signage? / Enable LED-strip? and write to config.
   - Ask whether to edit `config/config.env` for IOTA host, URLs, etc. (optional).
   - Provision the device with FIWARE and add heartbeat cron.
3. Start the command gateway: `python -m flask --app flask.app run --host=0.0.0.0 --port=5000`. Health: `GET /health`.

## FIWARE

- **Entity type:** `Yardmaster`
- **Attributes:** `deviceStatus`, `supportedType`, `displayUrl` (when Signage enabled)
- **Commands:** Signage — `listAssets`, `createAsset`, `deleteAsset`, `updatePlaylistOrder`, `updateAssetPatch`. LED-strip — `ledConfig`, `effectSet`, `playlistResume`, `playlistAdd`, `playlistRemove` (Glimmer v2026-02-05 API).

## Glimmer (LED-strip)

- `ledConfig` → `POST {GLIMMER_BASE_URL}/api/config` (new config structure: `runtime.effects_playlist`, `effects.rainbow`, etc.)
- `effectSet` → `POST /api/effect/set`
- `playlistResume` / `playlistAdd` / `playlistRemove` → same paths on Glimmer

## Debug

- `debug/list_devices.sh` — IOTA devices
- `debug/list_entities.sh` — Orion entities (needs `ORION_HOST`, `ORION_PORT` in config)
- `debug/list_group.sh` — IOTA service groups
