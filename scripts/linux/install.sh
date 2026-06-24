#!/bin/bash
# Script de instalacion de Mini App QR para Linux (Modo Kiosk)
# Uso: sudo ./install.sh

set -e

APP_NAME="mini_app_qr"
INSTALL_DIR="/opt/$APP_NAME"
DESKTOP_FILE="/usr/share/applications/${APP_NAME}.desktop"

echo "=========================================="
echo " Instalador de Mini App QR (Linux)"
echo "=========================================="

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Este script debe ejecutarse como root (sudo)."
    exit 1
fi

# Verificar que existe el ejecutable en el directorio actual
if [ ! -f "./mini_app_qr" ]; then
    echo "[ERROR] No se encontro el ejecutable 'mini_app_qr' en el directorio actual."
    echo "        Asegurate de descomprimir el paquete y ejecutar este script desde ahi."
    exit 1
fi

# Crear directorio de instalacion
echo "[1/5] Creando directorio de instalacion en $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Copiar archivos (excluyendo los propios scripts de instalacion)
echo "[2/5] Copiando archivos de la aplicacion..."
for item in ./*; do
    [ "$(basename "$item")" = "install.sh" ] && continue
    [ "$(basename "$item")" = "uninstall.sh" ] && continue
    cp -r "$item" "$INSTALL_DIR/"
done
chmod +x "$INSTALL_DIR/mini_app_qr"

# Copiar scripts de kiosk si existen en la carpeta scripts/
if [ -d "./scripts/linux" ]; then
    echo "       Copiando scripts de kiosk..."
    cp ./scripts/linux/start_kiosk.sh "$INSTALL_DIR/" 2>/dev/null || true
    cp ./scripts/linux/exit_kiosk.sh "$INSTALL_DIR/" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/start_kiosk.sh" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/exit_kiosk.sh" 2>/dev/null || true
fi

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

# Crear auto-inicio KIOSK para el usuario actual
echo "[4/5] Configurando auto-inicio KIOSK..."
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(eval echo ~$SUDO_USER)
    AUTOSTART_DIR="$USER_HOME/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"
    
    # Crear .desktop de autostart apuntando al script kiosk
    cat > "$AUTOSTART_DIR/${APP_NAME}.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Mini App QR Kiosk
Exec=$INSTALL_DIR/start_kiosk.sh
Icon=$INSTALL_DIR/data/flutter_assets/assets/icon.png
Terminal=false
Comment=Mini App QR - Modo Totem Kiosk
X-GNOME-Autostart-enabled=true
EOF
    
    chown "$SUDO_USER:$SUDO_USER" "$AUTOSTART_DIR/${APP_NAME}.desktop"
    chmod +x "$AUTOSTART_DIR/${APP_NAME}.desktop"
    echo "       Auto-inicio KIOSK activado para: $SUDO_USER"
    echo "       La app se bloqueara en pantalla completa al iniciar."
else
    echo "       Advertencia: No se detecto SUDO_USER. Auto-inicio no configurado."
    echo "       Ejecuta manualmente desde el usuario: ./setup_autostart.sh"
fi

echo "[5/5] Instalacion completada."
echo ""
echo "=========================================="
echo " COMANDOS UTILES:"
echo "=========================================="
echo "  Iniciar app manualmente:  $INSTALL_DIR/mini_app_qr"
echo "  Iniciar modo kiosk:       $INSTALL_DIR/start_kiosk.sh"
echo "  Salida de emergencia:     $INSTALL_DIR/exit_kiosk.sh"
echo "  Desinstalar:              sudo ./uninstall.sh"
echo "=========================================="
