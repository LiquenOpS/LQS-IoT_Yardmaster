# LQS-IoT Yardmaster

Multi-backend FIWARE gateway. Each backend (Glimmer/LEDStrip or Anthias/Signage) runs on its own port. Entity types: **LEDStrip**, **Signage**.

## Setup

1. Run `./setup.sh` once. It will:
   - Create `venv`, install deps (Flask, Waitress, PyYAML).
   - Prompt for common config (edge device IP, IOTA host, etc.).
   - Ask: How many Glimmer backends? How many Anthias backends?
   - Generate `config/config.yaml` with ports from 44011 upward.
   - Optionally edit config before saving.
   - Provision all backends with IOTA (option 2).
2. Start the gateway:
   - **As service:** Setup option 4, or manually install `ops/systemd/yardmaster.service`.
   - **Manual:** `./run.sh` — single process, multiple ports (Waitress).
   - Health: `GET http://host:44011/health` (per-backend port).

## Config

- `config/config.yaml` — YAML with `backends` list. Each backend: `type` (Glimmer|Anthias), `port`, `device_id`, `base_url`.
- Device ID format: `NeoPixel-{MAC6}{suffix}` (Glimmer), `Anthias-{MAC6}{suffix}` (Signage). Suffix A,B,C... shared across backends.

## FIWARE

- **Entity types:** `LEDStrip`, `Signage` (one per backend).
- **Attributes:** `deviceStatus`, `adopted`, `supportedEffects` (LEDStrip), `displayUrl` (Signage).
- **Commands:** Signage — `listAssets`, `createAsset`, `deleteAsset`, `updatePlaylistOrder`, `updateAssetPatch`. LEDStrip — `ledConfig`, `effectSet`, `playlistResume`, `playlistAdd`, `playlistRemove`, `setAdopted`.
