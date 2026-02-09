#!/bin/bash
# Interactive setup. Choose what to run; no parameters.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
CONFIG_DIR="$ROOT/config"

echo ""
echo "Yardmaster setup — what would you like to do?"
echo "  1) Install essentials (config, device info, venv)"
echo "  2) Provision (register device with IOTA)"
echo "  3) Install systemd (start on boot)"
echo "  4) Exit"
echo ""
read -p "Choice [1-4]: " CHOICE

case "$CHOICE" in
  1)
    # ---- Config ----
    CONFIG_CREATED=false
    if [ ! -f "$CONFIG_DIR/config.env" ]; then
      [ ! -d "$ROOT/config.example" ] && { echo "Error: config.example not found." >&2; exit 1; }
      echo "Creating config/ from config.example..."
      cp -r "$ROOT/config.example" "$ROOT/config"
      echo "  -> config/config.env created."
      CONFIG_CREATED=true
    fi

    # ---- Device ID / Name ----
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

    # ---- Capabilities (only when config was just created) ----
    if [ "$CONFIG_CREATED" = true ]; then
      echo ""
      read -p "Enable Signage (anthias)? [Y/n]: " Y
      ENABLE_SIGNAGE=true; [[ "$Y" =~ ^[nN] ]] && ENABLE_SIGNAGE=false
      read -p "Enable LED-strip (Glimmer)? [Y/n]: " Y
      ENABLE_LED_STRIP=true; [[ "$Y" =~ ^[nN] ]] && ENABLE_LED_STRIP=false
      sed -i "s/^ENABLE_SIGNAGE=.*/ENABLE_SIGNAGE=${ENABLE_SIGNAGE}/" "$CONFIG_DIR/config.env"
      sed -i "s/^ENABLE_LED_STRIP=.*/ENABLE_LED_STRIP=${ENABLE_LED_STRIP}/" "$CONFIG_DIR/config.env"
    fi

    read -p "Edit config/config.env for IOTA/URLs now? [y/N]: " EDIT
    [[ "$EDIT" =~ ^[yY] ]] && "${EDITOR:-nano}" "$CONFIG_DIR/config.env"

    # ---- Venv ----
    if [ ! -x "$ROOT/.venv/bin/python3" ]; then
      echo ""
      echo "Creating .venv and installing dependencies..."
      python3 -m venv "$ROOT/.venv"
      "$ROOT/.venv/bin/pip" install -r "$ROOT/requirements.txt"
      echo "  -> .venv ready."
    else
      echo ""
      "$ROOT/.venv/bin/pip" install -q -r "$ROOT/requirements.txt"
    fi

    chmod +x "$ROOT/run.sh"
    echo "Done. Use option 2 to provision (requires Pylon running)."
    ;;
  2)
    [ ! -f "$CONFIG_DIR/config.env" ] && { echo "Error: config/config.env not found. Run option 1 first." >&2; exit 1; }
    [ ! -f "$CONFIG_DIR/device.env" ] && { echo "Error: config/device.env not found. Run option 1 first." >&2; exit 1; }
    set -a
    source "$CONFIG_DIR/config.env"
    source "$CONFIG_DIR/device.env"
    set +a
    echo ""
    echo "==> Provisioning device..."
    bash "$ROOT/ops/provision_device.sh"
    echo "Done."
    ;;
  3)
    chmod +x "$ROOT/run.sh"
    read -p "Install systemd service (start on boot)? [y/N]: " Y
    if [[ "$Y" =~ ^[yY] ]]; then
      sudo -v
      SVC_FILE="/etc/systemd/system/yardmaster.service"
      sed "s|@INSTALL_DIR@|$ROOT|g" "$ROOT/ops/systemd/yardmaster.service" | sudo tee "$SVC_FILE" > /dev/null
      sudo systemctl daemon-reload
      sudo systemctl enable --now yardmaster
      echo "  -> $SVC_FILE installed and started."
    fi
    ;;
  4)
    echo "Bye."
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
esac
