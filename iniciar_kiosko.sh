#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

PYTHON_BIN="$ROOT_DIR/.venv/bin/python"
if [ ! -x "$PYTHON_BIN" ]; then
  PYTHON_BIN="$(command -v python3 || command -v python)"
fi

STARTED_CAM=0
CAM_PID=""
cleanup() {
  if [ "$STARTED_CAM" -eq 1 ] && [ -n "$CAM_PID" ]; then
    kill "$CAM_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if ! curl -sf http://127.0.0.1:5050/status >/dev/null 2>&1; then
  echo "[*] Iniciando servicio de cámara Edge (http://127.0.0.1:5050)..."
  "$PYTHON_BIN" "$ROOT_DIR/scripts/kiosk_camera_service.py" > "$ROOT_DIR/.kiosk_camera.log" 2>&1 &
  CAM_PID=$!
  STARTED_CAM=1
  sleep 2
fi

BIN_PATH="$ROOT_DIR/apps/kiosk_app/build/linux/x64/release/bundle/kiosk_app"
if [ -x "$BIN_PATH" ]; then
  echo "[*] Abriendo Kiosko Torniquete Edge (binario Linux release)..."
  "$BIN_PATH"
else
  echo "[*] Abriendo Kiosko Torniquete Edge (flutter run -d linux)..."
  cd "$ROOT_DIR/apps/kiosk_app"
  flutter run -d linux --no-tree-shake-icons
fi
