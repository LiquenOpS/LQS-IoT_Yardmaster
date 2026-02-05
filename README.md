# LQS-IoT Yardmaster

Single FIWARE device (entity type **Yardmaster**) that can expose **Signage** (anthias) and/or **LED-strip** (Glimmer) capabilities. One endpoint, one entity, attributes in camelCase (`deviceStatus`, `supportedType`, `displayUrl`).

## Setup

1. Copy the `config.example` folder to `config`, then edit `config/config.env` (`ENABLE_SIGNAGE` / `ENABLE_LED_STRIP`, IOTA host, `ANTHIAS_BASE_URL`, `GLIMMER_BASE_URL`). The `config/` folder is gitignored.
2. Run `./setup.sh` once (prompts for Device ID/Name, provisions device with FIWARE, adds heartbeat cron).
3. Start the command gateway: from repo root, `python -m flask --app flask.app run --host=0.0.0.0 --port=5000` (or set `YARDMASTER_PORT` in config).

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
