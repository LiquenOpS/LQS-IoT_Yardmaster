# Deployment Testing

Quick smoke test for Yardmaster → Glimmer (LED-strip) without Pylon/Odoo.

## Prerequisites

- Glimmer running (simulator or real)
- Yardmaster running
- `config/config.env`: `GLIMMER_BASE_URL`, `ENABLE_LED_STRIP=true`

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

3. **Verify health**
   ```bash
   curl http://localhost:5000/health
   # Expect: {"status":"ok"}
   ```

4. **Test: turn off LED**
   ```bash
   curl -X POST http://localhost:5000/command \
     -H "Content-Type: application/json" \
     -d '{"effectSet": {"effect": "off"}}'
   ```
   Expect: `{"success": true, "effect": "off", "playlist_mode": false}`

5. **Test: set effect** (e.g. fire)
   ```bash
   curl -X POST http://localhost:5000/command \
     -H "Content-Type: application/json" \
     -d '{"effectSet": {"effect": "fire"}}'
   ```

## Ports

- Yardmaster: `YARDMASTER_PORT` (default 5000)
- Glimmer: `api_port` (default 1129)
