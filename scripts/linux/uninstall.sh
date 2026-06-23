#!/bin/bash
# Script de desinstalacion de Mini App QR para Linux
# Uso: sudo ./uninstall.sh

set -e

APP_NAME="mini_app_qr"
INSTALL_DIR="/opt/$APP_NAME"
DESKTOP_FILE="/usr/share/applications/${APP_NAME}.desktop"
SYSTEMD_SERVICE="/etc/systemd/system/${APP_NAME}.service"

echo "=========================================="
echo " Desinstalador de Mini App QR (Linux)"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Este script debe ejecutarse como root (sudo)."
    exit 1
fi

echo "[1/4] Deteniendo servicio..."
if systemctl is-active --quiet "$APP_NAME"; then
    systemctl stop "$APP_NAME"
fi
systemctl disable "$APP_NAME" || true

echo "[2/4] Eliminando archivos de la aplicacion..."
rm -rf "$INSTALL_DIR"
rm -f "$DESKTOP_FILE"
rm -f "$SYSTEMD_SERVICE"

echo "[3/4] Recargando systemd..."
systemctl daemon-reload

echo "[4/4] Desinstalacion completada."
echo ""
echo "Mini App QR ha sido eliminado del sistema."
