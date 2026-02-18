# Deployment Testing

Quick smoke test for Yardmaster → Glimmer (LEDStrip) without Pylon/Odoo.

## Prerequisites

- Glimmer running (simulator or real)
- Yardmaster running (`./setup.sh` → Install essentials, add at least one Glimmer backend)

## Steps

1. **Start Glimmer** (terminal 1)
   ```bash
   cd /path/to/Glimmer
   ./run.sh --simulator
   ```

2. **Start Yardmaster** (terminal 2)
   ```bash
   cd /path/to/LQS-IoT_Yardmaster
   ./run.sh
   ```

3. **Verify health** (per-backend port, e.g. Glimmer suffix A → 33365)
   ```bash
   curl http://localhost:33365/health
   # Expect: {"status":"ok"}
   ```

4. **Test: turn off LED** (use the port for your Glimmer backend)
   ```bash
   curl -X POST http://localhost:33365/command \
     -H "Content-Type: application/json" \
     -d '{"effectSet": {"effect": "off"}}'
   ```
   Expect: `{"success": true, "effect": "off", "playlist_mode": false}`

5. **Test: set effect** (e.g. fire)
   ```bash
   curl -X POST http://localhost:33365/command \
     -H "Content-Type: application/json" \
     -d '{"effectSet": {"effect": "fire"}}'
   ```

## Ports

- Yardmaster per-backend: 33300 + ASCII(suffix), e.g. Glimmer A → 33365
- Glimmer: `api_port` (default 1129)
