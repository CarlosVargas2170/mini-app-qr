#!/bin/bash
# Configura auto-inicio de Mini App QR para el usuario actual.
# En modo kiosk: bloquea salidas accidentales y reinicia la app si falla.
# Uso: ./setup_autostart.sh

APP_NAME="mini_app_qr"
INSTALL_DIR="/opt/$APP_NAME"
AUTOSTART_DIR="$HOME/.config/autostart"
DESKTOP_FILE="$AUTOSTART_DIR/${APP_NAME}.desktop"

echo "=========================================="
echo " Configurando auto-inicio Kiosk"
echo "=========================================="

# Verificar que la app este instalada
if [ ! -f "$INSTALL_DIR/mini_app_qr" ]; then
    echo "[ERROR] No se encontro la app en $INSTALL_DIR"
    echo "        Ejecuta primero: sudo ./install.sh"
    exit 1
fi

# Verificar que el script kiosk exista
if [ ! -f "$INSTALL_DIR/start_kiosk.sh" ]; then
    echo "[ERROR] No se encontro start_kiosk.sh en $INSTALL_DIR"
    exit 1
fi

# Crear directorio autostart si no existe
mkdir -p "$AUTOSTART_DIR"

# Crear el archivo .desktop de auto-inicio (apunta al script kiosk)
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Type=Application
Name=Mini App QR Kiosk
Exec=$INSTALL_DIR/start_kiosk.sh
Icon=$INSTALL_DIR/data/flutter_assets/assets/icon.png
Terminal=false
Comment=Mini App QR - Modo Totem Kiosk
X-GNOME-Autostart-enabled=true
EOF

chmod +x "$DESKTOP_FILE"

echo "[OK] Auto-inicio Kiosk configurado."
echo "     Archivo: $DESKTOP_FILE"
echo ""
echo "La app se iniciara automaticamente en MODO KIOSK al iniciar sesion."
echo ""
echo "SALIDA DE EMERGENCIA (desde SSH):"
echo "  /opt/mini_app_qr/exit_kiosk.sh"
echo "  o manualmente: touch /tmp/exit_mini_app_qr"
echo ""
echo "Para desactivar el auto-inicio:"
echo "  rm $DESKTOP_FILE"
echo "=========================================="
