#!/bin/bash
# ============================================================
# Salida de Emergencia - Modo Kiosk
# ============================================================
# Uso (desde SSH):
#   ./exit_kiosk.sh
#
# Esto envia una senal al script start_kiosk.sh para que:
#   1. Mate la app Mini App QR.
#   2. Restaure los atajos de teclado de GNOME.
#   3. Libere el sistema.
# ============================================================

EXIT_FLAG="/tmp/exit_mini_app_qr"
PID_FILE="/tmp/mini_app_qr_kiosk.pid"

echo "Enviando senal de salida al modo kiosk..."

if [ -f "$PID_FILE" ]; then
    touch "$EXIT_FLAG"
    echo "[OK] Senal enviada. El kiosk se detendra en ~3 segundos."
    echo "     Si no se detiene, ejecuta manualmente:"
    echo "       pkill -f start_kiosk.sh"
    echo "       pkill -x mini_app_qr"
else
    echo "[ADVERTENCIA] No se detecto el proceso kiosk corriendo."
    echo "              Forzando cierre de la app..."
    pkill -x "mini_app_qr" 2>/dev/null
    touch "$EXIT_FLAG"
fi
