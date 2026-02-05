#!/bin/bash
# One-time setup: copy config.example to config, then run this once per device.

SCRIPT_PATH=$(readlink -f "$0")
ROOT=$(dirname "$SCRIPT_PATH")
[ -f "$ROOT/config/config.env" ] && CONFIG_DIR="$ROOT/config" || CONFIG_DIR="$ROOT"

if [ ! -f "$CONFIG_DIR/config.env" ]; then
  echo "Error: No config found. Copy config.example to config and edit config/config.env"
  exit 1
fi

if [ ! -f "$CONFIG_DIR/device.env" ]; then
  echo "Input required to set up the device."
  read -p "Device ID: " DEVICE_ID
  read -p "Device Name: " DEVICE_NAME
  mkdir -p "$CONFIG_DIR"
  echo "export DEVICE_ID=${DEVICE_ID}" > "$CONFIG_DIR/device.env"
  echo "export DEVICE_NAME=${DEVICE_NAME}" >> "$CONFIG_DIR/device.env"
  echo "Info saved to $CONFIG_DIR/device.env"
fi

set -a
source "$CONFIG_DIR/config.env"
source "$CONFIG_DIR/device.env"
set +a

echo "Provisioning Yardmaster device..."
bash "$ROOT/setup/provision_device.sh"

echo "Setting up cron for heartbeat..."
CRON_CMD="*/2 * * * * $ROOT/jobs/send_heartbeat.sh"
if ! crontab -l 2>/dev/null | grep -qF "$ROOT/jobs/send_heartbeat.sh"; then
  (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
  echo "Added heartbeat every 2 minutes."
else
  echo "Heartbeat cron already exists."
fi

echo "Done. Start the Flask app: python -m flask --app flask.app run --host=0.0.0.0 --port=${YARDMASTER_PORT:-5000}"
