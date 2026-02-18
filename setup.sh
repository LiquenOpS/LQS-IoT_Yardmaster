#!/bin/bash
# Interactive setup. Choose what to run; no parameters.

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
CONFIG_DIR="$ROOT/config"

echo ""
echo "Yardmaster setup — what would you like to do?"
echo "  1) Install essentials (config, venv)"
echo "  2) Provision (register all backends with IOTA)"
echo "  3) Deprovision (remove all from IOTA)"
echo "  4) Install systemd (start on boot)"
echo "  5) Uninstall (deprovision, stop, remove systemd)"
echo "  6) Exit"
echo ""
read -p "Choice [1-6]: " CHOICE

# Try to detect edge device IP (for IOTA callback base). Fallback: localhost.
get_edge_ip() {
  _ip=""
  if command -v ip &>/dev/null; then
    _ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
  fi
  if [ -z "$_ip" ] && command -v hostname &>/dev/null; then
    _ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  fi
  [ -n "$_ip" ] && echo "$_ip" || echo "localhost"
}

# Get MAC last 6 for device_id suffix
get_mac6() {
  _mac=""
  if [ -d /sys/class/net ]; then
    for _iface in /sys/class/net/*/; do
      _iface=$(basename "$_iface")
      [[ "$_iface" == lo ]] || [[ "$_iface" == docker* ]] || [[ "$_iface" == veth* ]] || \
      [[ "$_iface" == br-* ]] || [[ "$_iface" == virbr* ]] || [[ "$_iface" == tun* ]] || [[ "$_iface" == tap* ]] && continue
      [ -f "/sys/class/net/$_iface/address" ] || continue
      _m=$(cat "/sys/class/net/$_iface/address" 2>/dev/null | tr -d ':' | tr '[:upper:]' '[:lower:]')
      [ -n "$_m" ] && [ "${#_m}" -ge 6 ] && _mac="${_m: -6}" && break
    done
  fi
  [ -z "$_mac" ] && _mac="000001"
  echo "$_mac"
}

SUFFIXES="ABCDEFGHIJKLMNOPQRSTUVWXYZ"

case "$CHOICE" in
  1)
    CONFIG_CREATED=false
    if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
      [ ! -f "$ROOT/config.example/config.yaml.template" ] && { echo "Error: config.example/config.yaml.template not found." >&2; exit 1; }
      echo "Creating config/..."
      mkdir -p "$CONFIG_DIR"
      CONFIG_CREATED=true
    fi

    # Reset for re-run
    if [ -f "$CONFIG_DIR/config.yaml" ]; then
      read -p "Reset config (re-prompt all)? [y/N]: " RESET
      if [[ "$RESET" =~ ^[yY] ]]; then
        CONFIG_CREATED=true
      fi
    fi

    if [ "$CONFIG_CREATED" = true ]; then
      echo ""
      echo "== Common =="
      _default_ip=$(get_edge_ip)
      read -p "Edge device IP (for IOTA callbacks) [${_default_ip}]: " EDGE_IP
      EDGE_IP="${EDGE_IP:-$_default_ip}"
      read -p "IOTA host [localhost]: " IOTA_HOST
      IOTA_HOST="${IOTA_HOST:-localhost}"
      read -p "IOTA North port [4041]: " IOTA_NORTH
      IOTA_NORTH="${IOTA_NORTH:-4041}"
      read -p "IOTA South port [7896]: " IOTA_SOUTH
      IOTA_SOUTH="${IOTA_SOUTH:-7896}"
      read -p "API key [YardmasterKey]: " API_KEY
      API_KEY="${API_KEY:-YardmasterKey}"
      read -p "FIWARE service [lqs_iot]: " FIWARE_SVC
      FIWARE_SVC="${FIWARE_SVC:-lqs_iot}"

      echo ""
      echo "== Backends =="
      read -p "How many Glimmer (LEDStrip) backends? [0]: " N_GLIMMER
      N_GLIMMER="${N_GLIMMER:-0}"
      read -p "How many Anthias (Signage) backends? [0]: " N_ANTHIAS
      N_ANTHIAS="${N_ANTHIAS:-0}"
      [ "$N_GLIMMER" -eq 0 ] && [ "$N_ANTHIAS" -eq 0 ] && N_ANTHIAS=1

      MAC6=$(get_mac6)
      BACKENDS=""
      IDX=0

      for ((i=0; i<N_GLIMMER; i++)); do
        SUF="${SUFFIXES:$IDX:1}"
        PORT=$((33300 + $(printf '%d' "'$SUF")))
        DEF_ID="NeoPixel-${MAC6}-${SUF}"
        read -p "  Glimmer $((i+1)) Device ID or Name [${DEF_ID}]: " DID
        DID="${DID:-$DEF_ID}"
        read -p "  Glimmer $((i+1)) base_url [http://localhost:1129]: " BASE
        BASE="${BASE:-http://localhost:1129}"
        # device_id: lowercase for IOTA; device_name: as entered (can have caps)
        DID_LOWER=$(echo "$DID" | tr '[:upper:]' '[:lower:]')
        BACKENDS="${BACKENDS}
  - type: Glimmer
    port: $PORT
    device_id: \"$DID_LOWER\"
    device_name: \"$DID\"
    base_url: \"$BASE\""
        ((IDX++)) || true
      done

      for ((i=0; i<N_ANTHIAS; i++)); do
        SUF="${SUFFIXES:$IDX:1}"
        PORT=$((33300 + $(printf '%d' "'$SUF")))
        DEF_ID="Anthias-${MAC6}-${SUF}"
        read -p "  Anthias $((i+1)) Device ID or Name [${DEF_ID}]: " DID
        DID="${DID:-$DEF_ID}"
        read -p "  Anthias $((i+1)) base_url [http://localhost:8000/api/v2/assets]: " BASE
        BASE="${BASE:-http://localhost:8000/api/v2/assets}"
        DID_LOWER=$(echo "$DID" | tr '[:upper:]' '[:lower:]')
        BACKENDS="${BACKENDS}
  - type: Anthias
    port: $PORT
    device_id: \"$DID_LOWER\"
    device_name: \"$DID\"
    base_url: \"$BASE\""
        ((IDX++)) || true
      done

      while IFS= read -r line; do
        if [[ "$line" == "{{BACKENDS}}" ]]; then
          printf '%s' "$BACKENDS"
        else
          line="${line//\{\{EDGE_IP\}\}/$EDGE_IP}"
          line="${line//\{\{IOTA_HOST\}\}/$IOTA_HOST}"
          line="${line//\{\{IOTA_NORTH\}\}/$IOTA_NORTH}"
          line="${line//\{\{IOTA_SOUTH\}\}/$IOTA_SOUTH}"
          line="${line//\{\{API_KEY\}\}/$API_KEY}"
          line="${line//\{\{FIWARE_SVC\}\}/$FIWARE_SVC}"
          echo "$line"
        fi
      done < "$ROOT/config.example/config.yaml.template" > "$CONFIG_DIR/config.yaml"
      echo "  -> config/config.yaml written."
    fi

    read -p "Edit config/config.yaml now? [y/N]: " EDIT
    [[ "$EDIT" =~ ^[yY] ]] && "${EDITOR:-vi}" "$CONFIG_DIR/config.yaml"

    # Venv
    if [ ! -x "$ROOT/venv/bin/python3" ]; then
      echo ""
      echo "Creating venv and installing dependencies..."
      python3 -m venv "$ROOT/venv"
      "$ROOT/venv/bin/pip" install -r "$ROOT/requirements.txt"
      echo "  -> venv ready."
    else
      "$ROOT/venv/bin/pip" install -q -r "$ROOT/requirements.txt"
    fi

    chmod +x "$ROOT/run.sh"
    echo "Done. Use option 2 to Provision (requires Pylon running)."
    ;;
  2)
    [ ! -f "$CONFIG_DIR/config.yaml" ] && { echo "Error: config/config.yaml not found. Run option 1 first." >&2; exit 1; }
    echo ""
    echo "==> Provisioning all backends with IOTA..."
    "$ROOT/venv/bin/python3" "$ROOT/ops/provision_all.py"
    echo "Done. Devices will appear in Odoo after first heartbeat."
    ;;
  3)
    [ ! -f "$CONFIG_DIR/config.yaml" ] && { echo "Error: config/config.yaml not found." >&2; exit 1; }
    "$ROOT/venv/bin/python3" "$ROOT/ops/deprovision_all.py"
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
    if [ -f "$CONFIG_DIR/config.yaml" ]; then
      read -p "Deprovision all backends from IOTA first? [Y/n]: " Y
      if [[ ! "$Y" =~ ^[nN] ]]; then
        "$ROOT/venv/bin/python3" "$ROOT/ops/deprovision_all.py" 2>/dev/null || true
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
