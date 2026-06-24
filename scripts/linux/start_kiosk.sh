#!/bin/bash
# ============================================================
# Modo Kiosk para Mini App QR
# ============================================================
# Este script bloquea las salidas accidentales del totem:
#   - Deshabilita Alt+F4, Alt+Tab, Super, etc.
#   - Mantiene la app siempre al frente.
#   - Reinicia la app automaticamente si se cierra.
#
# SALIDA DE EMERGENCIA (desde SSH):
#   touch /tmp/exit_mini_app_qr
#
# ============================================================

APP="/opt/mini_app_qr/mini_app_qr"
EXIT_FLAG="/tmp/exit_mini_app_qr"
PID_FILE="/tmp/mini_app_qr_kiosk.pid"

echo "[Kiosk] Iniciando modo totem..."

# Limpiar flag de salida si existe de un reinicio anterior
rm -f "$EXIT_FLAG"

# Deshabilitar atajos de teclado peligrosos en GNOME
if command -v gsettings &> /dev/null; then
    echo "[Kiosk] Bloqueando atajos de teclado..."
    gsettings set org.gnome.desktop.wm.keybindings close "[]"
    gsettings set org.gnome.desktop.wm.keybindings switch-applications "[]"
    gsettings set org.gnome.desktop.wm.keybindings switch-windows "[]"
    gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "[]"
    gsettings set org.gnome.desktop.wm.keybindings switch-windows-backward "[]"
    gsettings set org.gnome.desktop.wm.keybindings show-desktop "[]"
    gsettings set org.gnome.shell.keybindings toggle-overview "[]"
    gsettings set org.gnome.shell.keybindings toggle-application-view "[]"
    gsettings set org.gnome.mutter.keybindings toggle-tiled-left "[]"
    gsettings set org.gnome.mutter.keybindings toggle-tiled-right "[]"
fi

# Ocultar cursor del mouse (opcional, util en totems touch)
if command -v unclutter &> /dev/null; then
    echo "[Kiosk] Ocultando cursor..."
    unclutter -idle 0.1 &
fi

# Guardar PID del script kiosk
echo $$ > "$PID_FILE"

# Loop principal: mantiene la app viva
while [ ! -f "$EXIT_FLAG" ]; do
    if ! pgrep -x "mini_app_qr" > /dev/null; then
        echo "[Kiosk] App no detectada. Reiniciando..."
        "$APP" &
        sleep 4
    fi

    # Asegurar que la ventana este siempre al frente
    if command -v xdotool &> /dev/null; then
        WINDOW_ID=$(xdotool search --name "Mini App QR" | head -1)
        if [ -n "$WINDOW_ID" ]; then
            xdotool windowactivate "$WINDOW_ID" 2>/dev/null
            xdotool windowraise "$WINDOW_ID" 2>/dev/null
        fi
    fi

    sleep 2
done

echo "[Kiosk] Senal de salida detectada. Restaurando sistema..."

# Matar la app
pkill -x "mini_app_qr" 2>/dev/null
sleep 1

# Restaurar atajos de teclado
if command -v gsettings &> /dev/null; then
    echo "[Kiosk] Restaurando atajos de teclado..."
    gsettings reset org.gnome.desktop.wm.keybindings close
    gsettings reset org.gnome.desktop.wm.keybindings switch-applications
    gsettings reset org.gnome.desktop.wm.keybindings switch-windows
    gsettings reset org.gnome.desktop.wm.keybindings switch-applications-backward
    gsettings reset org.gnome.desktop.wm.keybindings switch-windows-backward
    gsettings reset org.gnome.desktop.wm.keybindings show-desktop
    gsettings reset org.gnome.shell.keybindings toggle-overview
    gsettings reset org.gnome.shell.keybindings toggle-application-view
    gsettings reset org.gnome.mutter.keybindings toggle-tiled-left
    gsettings reset org.gnome.mutter.keybindings toggle-tiled-right
fi

# Matar procesos auxiliares
pkill unclutter 2>/dev/null

# Limpiar archivos temporales
rm -f "$EXIT_FLAG" "$PID_FILE"

echo "[Kiosk] Detenido. Podes cerrar la sesion o reiniciar."
