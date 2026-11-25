@echo off
setlocal
set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"

set "PYTHON_BIN=%ROOT_DIR%\.venv\Scripts\python.exe"
if not exist "%PYTHON_BIN%" set "PYTHON_BIN=python"

echo [*] Iniciando servicio de camara Edge (http://127.0.0.1:5050)...
start "SIRAD Camara Edge" /MIN cmd /c "cd /d ""%ROOT_DIR%"" && ""%PYTHON_BIN%"" ""%ROOT_DIR%\scripts\kiosk_camera_service.py"""

timeout /t 2 /nobreak >nul

echo [*] Abriendo Kiosko Torniquete Edge (Flutter Windows)...
cd /d "%ROOT_DIR%\apps\kiosk_app"
flutter run -d windows
