#!/bin/bash
# Script de empaquetado de Mini App QR para distribucion Linux
# Uso: ./scripts/package_linux.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build/linux/x64/release/bundle"
OUTPUT_DIR="$PROJECT_DIR/dist"
VERSION=$(grep -E '^version:' "$PROJECT_DIR/pubspec.yaml" | awk '{print $2}' | tr -d '"')
APP_NAME="mini_app_qr"
PACKAGE_NAME="${APP_NAME}_linux_v${VERSION}"

echo "=========================================="
echo " Empaquetado de Mini App QR (Linux)"
echo "=========================================="
echo "Version detectada: $VERSION"
echo ""

# Verificar que existe el build
if [ ! -d "$BUILD_DIR" ]; then
    echo "[ERROR] No se encontro el build en:"
    echo "        $BUILD_DIR"
    echo ""
    echo "Primero debes compilar la app. Ejecuta:"
    echo "  (Desde Windows PowerShell) .\\build_linux.ps1"
    echo "  (Desde Linux)              flutter build linux --release"
    exit 1
fi

# Crear directorio de salida
mkdir -p "$OUTPUT_DIR"

# Crear carpeta temporal para empaquetar
TEMP_DIR=$(mktemp -d)
mkdir -p "$TEMP_DIR/$PACKAGE_NAME"

# Copiar archivos del build
echo "[1/3] Copiando archivos del build..."
cp -r "$BUILD_DIR"/* "$TEMP_DIR/$PACKAGE_NAME/"

# Copiar scripts de instalacion
echo "[2/3] Copiando scripts de instalacion..."
cp -r "$SCRIPT_DIR/linux/install.sh" "$TEMP_DIR/$PACKAGE_NAME/"
cp -r "$SCRIPT_DIR/linux/uninstall.sh" "$TEMP_DIR/$PACKAGE_NAME/"
chmod +x "$TEMP_DIR/$PACKAGE_NAME/install.sh"
chmod +x "$TEMP_DIR/$PACKAGE_NAME/uninstall.sh"

# Empaquetar como tar.gz
echo "[3/3] Generando archivos de distribucion..."
cd "$TEMP_DIR"
tar -czf "$OUTPUT_DIR/${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"
zip -r -q "$OUTPUT_DIR/${PACKAGE_NAME}.zip" "$PACKAGE_NAME"

# Limpiar
rm -rf "$TEMP_DIR"

echo ""
echo "=========================================="
echo " EMPAQUETADO COMPLETADO"
echo "=========================================="
echo "Archivos generados en: $OUTPUT_DIR"
echo ""
echo "  - ${PACKAGE_NAME}.tar.gz  (Linux nativo)"
echo "  - ${PACKAGE_NAME}.zip     (Compatible multiplataforma)"
echo ""
echo "Instrucciones de instalacion en el destino:"
echo "  1. Transferir el .tar.gz a la maquina Linux"
echo "  2. Descomprimir: tar -xzvf ${PACKAGE_NAME}.tar.gz"
echo "  3. Entrar a la carpeta: cd $PACKAGE_NAME"
echo "  4. Instalar: sudo ./install.sh"
echo "=========================================="
