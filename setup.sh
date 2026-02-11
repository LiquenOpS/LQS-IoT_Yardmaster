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
echo "  3) Deprovision (remove from IOTA and Orion)"
echo "  4) Install systemd (start on boot)"
echo "  5) Uninstall (deprovision, stop, remove systemd)"
echo "  6) Exit"
echo ""
read -p "Choice [1-6]: " CHOICE

case "$CHOICE" in
  1)
    # ---- Config ----
    CONFIG_CREATED=false
    RESET_DEVICE=false
    if [ -f "$CONFIG_DIR/device.env" ]; then
      read -p "Reset device config for re-test (re-prompt device ID, name, capabilities)? [y/N]: " RESET
      if [[ "$RESET" =~ ^[yY] ]]; then
        rm -f "$CONFIG_DIR/device.env"
        RESET_DEVICE=true
      fi
    fi
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

    # ---- Capabilities (when config just created or reset for re-test) ----
    if [ "$CONFIG_CREATED" = true ] || [ "$RESET_DEVICE" = true ]; then
      echo ""
      read -p "Enable Signage (anthias)? [Y/n]: " Y
      ENABLE_SIGNAGE=true; [[ "$Y" =~ ^[nN] ]] && ENABLE_SIGNAGE=false
      read -p "Enable LEDStrip (Glimmer)? [Y/n]: " Y
      ENABLE_LED_STRIP=true; [[ "$Y" =~ ^[nN] ]] && ENABLE_LED_STRIP=false
      sed -i "s/^ENABLE_SIGNAGE=.*/ENABLE_SIGNAGE=${ENABLE_SIGNAGE}/" "$CONFIG_DIR/config.env"
      sed -i "s/^ENABLE_LED_STRIP=.*/ENABLE_LED_STRIP=${ENABLE_LED_STRIP}/" "$CONFIG_DIR/config.env"
    fi

    echo "  Important: set IOTA_HOST (where Pylon runs), YARDMASTER_HOST (this unit's address), YARDMASTER_PORT, API_KEY."
    read -p "Edit config/config.env now? [y/N]: " EDIT
    [[ "$EDIT" =~ ^[yY] ]] && "${EDITOR:-vi}" "$CONFIG_DIR/config.env"

    # ---- Venv ----
    if [ ! -x "$ROOT/venv/bin/python3" ]; then
      echo ""
      echo "Creating venv and installing dependencies..."
      python3 -m venv "$ROOT/venv"
      "$ROOT/venv/bin/pip" install -r "$ROOT/requirements.txt"
      echo "  -> venv ready."
    else
      echo ""
      "$ROOT/venv/bin/pip" install -q -r "$ROOT/requirements.txt"
    fi

    chmod +x "$ROOT/run.sh"
    echo "Done. Use option 2 to Provision (requires Pylon running)."
    ;;
  2)
    [ ! -f "$CONFIG_DIR/config.env" ] && { echo "Error: config/config.env not found. Run option 1 first." >&2; exit 1; }
    [ ! -f "$CONFIG_DIR/device.env" ] && { echo "Error: config/device.env not found. Run option 1 first." >&2; exit 1; }
    set -a
    source "$CONFIG_DIR/config.env"
    source "$CONFIG_DIR/device.env"
    set +a
    echo ""
    echo "==> Provisioning device with IOTA..."
    echo "    (IOTA must be running at ${IOTA_HOST:-localhost}:${IOTA_NORTH_PORT:-4041})"
    bash "$ROOT/ops/provision_device.sh"
    echo "Done. If status 200/201, device is registered. It will appear in Odoo after first heartbeat."
    ;;
  3)
    [ ! -f "$CONFIG_DIR/config.env" ] && { echo "Error: config/config.env not found. Run option 1 first." >&2; exit 1; }
    [ ! -f "$CONFIG_DIR/device.env" ] && { echo "Error: config/device.env not found. Run option 1 first." >&2; exit 1; }
    bash "$ROOT/ops/deprovision_device.sh"
    ;;
  4)
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
  5)
    echo "==> Uninstalling Yardmaster..."
    SVC_FILE="/etc/systemd/system/yardmaster.service"
    if [ -f "$SVC_FILE" ]; then
      sudo -v
      sudo systemctl stop yardmaster 2>/dev/null || true
      sudo systemctl disable yardmaster 2>/dev/null || true
      sudo rm -f "$SVC_FILE"
      sudo systemctl daemon-reload
      echo "  -> systemd service removed."
    fi
    if [ -f "$CONFIG_DIR/config.env" ] && [ -f "$CONFIG_DIR/device.env" ]; then
      read -p "Deprovision device from IOTA/Orion first? [Y/n]: " Y
      if [[ ! "$Y" =~ ^[nN] ]]; then
        bash "$ROOT/ops/deprovision_device.sh"
      fi
    fi
    read -p "Remove config/ and venv? [y/N]: " Y
    if [[ "$Y" =~ ^[yY] ]]; then
      rm -rf "$CONFIG_DIR" "$ROOT/venv"
      echo "  -> config and venv removed."
    fi
    echo "Done."
    ;;
  6)
    echo "Bye."
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
esac
