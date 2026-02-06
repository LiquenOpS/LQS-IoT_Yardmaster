#!/bin/bash
# One-time setup: creates config from template, prompts for device and options, then provisions.

set -e
SCRIPT_PATH=$(readlink -f "$0")
ROOT=$(dirname "$SCRIPT_PATH")

# ---- 1. Ensure config dir (copy from config.example if missing) ----
CONFIG_CREATED=false
if [ ! -f "$ROOT/config/config.env" ]; then
  if [ ! -d "$ROOT/config.example" ]; then
    echo "Error: config.example not found."
    exit 1
  fi
  echo "Creating config/ from config.example..."
  cp -r "$ROOT/config.example" "$ROOT/config"
  echo "  -> config/config.env created."
  CONFIG_CREATED=true
fi

CONFIG_DIR="$ROOT/config"

# ---- 2. Device ID / Name (interactive if missing) ----
if [ ! -f "$CONFIG_DIR/device.env" ]; then
  echo ""
  read -p "Device ID [yardmaster-01]: " DEVICE_ID
  DEVICE_ID="${DEVICE_ID:-yardmaster-01}"
  read -p "Device Name [Yardmaster-01]: " DEVICE_NAME
  DEVICE_NAME="${DEVICE_NAME:-Yardmaster-01}"
  echo "export DEVICE_ID=${DEVICE_ID}" > "$CONFIG_DIR/device.env"
  echo "export DEVICE_NAME=${DEVICE_NAME}" >> "$CONFIG_DIR/device.env"
  echo "  -> config/device.env saved."
fi

# ---- 3. Capabilities (only when config was just created) ----
if [ "$CONFIG_CREATED" = true ]; then
  echo ""
  read -p "Enable Signage (anthias)? [Y/n]: " Y
  ENABLE_SIGNAGE=true; [[ "$Y" =~ ^[nN] ]] && ENABLE_SIGNAGE=false
  read -p "Enable LED-strip (Glimmer)? [Y/n]: " Y
  ENABLE_LED_STRIP=true; [[ "$Y" =~ ^[nN] ]] && ENABLE_LED_STRIP=false
  sed -i "s/^ENABLE_SIGNAGE=.*/ENABLE_SIGNAGE=${ENABLE_SIGNAGE}/" "$CONFIG_DIR/config.env"
  sed -i "s/^ENABLE_LED_STRIP=.*/ENABLE_LED_STRIP=${ENABLE_LED_STRIP}/" "$CONFIG_DIR/config.env"
fi

# ---- 4. Optional: edit full config (IOTA host, URLs, etc.) ----
echo ""
read -p "Edit config/config.env for IOTA/URLs now? [y/N]: " EDIT
if [[ "$EDIT" =~ ^[yY] ]]; then
  "${EDITOR:-nano}" "$CONFIG_DIR/config.env"
fi

# ---- 5. Venv and deps ----
if [ ! -x "$ROOT/.venv/bin/python3" ]; then
  echo "Creating .venv and installing dependencies..."
  python3 -m venv "$ROOT/.venv"
  "$ROOT/.venv/bin/pip" install -r "$ROOT/requirements.txt"
  echo "  -> .venv ready."
else
  echo "Checking dependencies in .venv..."
  "$ROOT/.venv/bin/pip" install -q -r "$ROOT/requirements.txt"
fi

# ---- 6. Source and provision ----
set -a
source "$CONFIG_DIR/config.env"
source "$CONFIG_DIR/device.env"
set +a

echo ""
echo "Provisioning Yardmaster device..."
bash "$ROOT/setup/provision_device.sh"

# ---- 7. Optional: install systemd service ----
chmod +x "$ROOT/run.sh"
echo ""
read -p "Install systemd service (start on boot, restart on failure)? [y/N]: " INSTALL_SVC
if [[ "$INSTALL_SVC" =~ ^[yY] ]]; then
  echo "Installing service requires sudo (you may be prompted for password)."
  sudo -v
  SVC_FILE="/etc/systemd/system/yardmaster.service"
  sed "s|@INSTALL_DIR@|$ROOT|g" "$ROOT/systemd/yardmaster.service" | sudo tee "$SVC_FILE" > /dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable --now yardmaster
  echo "  -> $SVC_FILE installed and started."
else
  echo "Run manually: $ROOT/run.sh"
fi
