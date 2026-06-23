#!/bin/bash
# Script de instalacion de Mini App QR para Linux
# Uso: ./install.sh

set -e

APP_NAME="mini_app_qr"
INSTALL_DIR="/opt/$APP_NAME"
BUNDLE_DIR="./bundle"
DESKTOP_FILE="/usr/share/applications/${APP_NAME}.desktop"
SYSTEMD_SERVICE="/etc/systemd/system/${APP_NAME}.service"

echo "=========================================="
echo " Instalador de Mini App QR (Linux)"
echo "=========================================="

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Este script debe ejecutarse como root (sudo)."
    exit 1
fi

# Verificar que existe la carpeta bundle
if [ ! -d "$BUNDLE_DIR" ]; then
    echo "[ERROR] No se encontro la carpeta '$BUNDLE_DIR'."
    echo "        Asegurate de descomprimir el paquete antes de instalar."
    exit 1
fi

# Crear directorio de instalacion
echo "[1/5] Creando directorio de instalacion en $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Copiar archivos
echo "[2/5] Copiando archivos de la aplicacion..."
cp -r "$BUNDLE_DIR"/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/mini_app_qr"

# Crear archivo .desktop (acceso directo en el menu)
echo "[3/5] Creando acceso directo..."
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Mini App QR
Comment=Aplicacion de pago QR
Exec=$INSTALL_DIR/mini_app_qr
Icon=$INSTALL_DIR/data/flutter_assets/assets/icon.png
Type=Application
Terminal=false
Categories=Office;Finance;
EOF

chmod +x "$DESKTOP_FILE"

# Crear servicio systemd para auto-inicio
echo "[4/5] Creando servicio systemd..."
cat > "$SYSTEMD_SERVICE" << EOF
[Unit]
Description=Mini App QR
After=graphical.target

[Service]
Type=simple
User=$SUDO_USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SUDO_USER/.Xauthority
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/mini_app_qr
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

# Recargar systemd
systemctl daemon-reload
systemctl enable "$APP_NAME.service"

echo "[5/5] Instalacion completada."
echo ""
echo "=========================================="
echo " COMANDOS UTILES:"
echo "=========================================="
echo "  Iniciar app manualmente:  ./$INSTALL_DIR/mini_app_qr"
echo "  Iniciar como servicio:    sudo systemctl start $APP_NAME"
echo "  Ver estado del servicio:  sudo systemctl status $APP_NAME"
echo "  Detener servicio:         sudo systemctl stop $APP_NAME"
echo "  Desinstalar:              sudo ./uninstall.sh"
echo "=========================================="
