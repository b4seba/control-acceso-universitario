#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

PYTHON_BIN="$ROOT_DIR/.venv/bin/python"
if [ ! -x "$PYTHON_BIN" ]; then
  PYTHON_BIN="$(command -v python3 || command -v python)"
fi

if ! curl -sf http://127.0.0.1:5050/status >/dev/null 2>&1; then
  echo "[*] Iniciando servicio de cámara Edge (http://127.0.0.1:5050)..."
  nohup "$PYTHON_BIN" "$ROOT_DIR/scripts/kiosk_camera_service.py" > "$ROOT_DIR/.kiosk_camera.log" 2>&1 &
  sleep 2
fi

BIN_PATH="$ROOT_DIR/apps/kiosk_app/build/linux/x64/release/bundle/kiosk_app"
if [ -x "$BIN_PATH" ]; then
  echo "[*] Abriendo Kiosko Torniquete Edge (binario Linux release)..."
  exec "$BIN_PATH"
else
  echo "[*] Abriendo Kiosko Torniquete Edge (flutter run -d linux)..."
  cd "$ROOT_DIR/apps/kiosk_app"
  exec flutter run -d linux
fi
