# Empaquetado de Mini App QR para distribucion Linux (desde Windows)
# Uso: .\scripts\package_linux.ps1

$ErrorActionPreference = "Stop"

$ProjectDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$BuildDir = Join-Path $ProjectDir "build\linux\x64\release\bundle"
$OutputDir = Join-Path $ProjectDir "dist"
$ScriptsLinuxDir = Join-Path $ProjectDir "scripts\linux"

# Leer version del pubspec.yaml
$Pubspec = Get-Content (Join-Path $ProjectDir "pubspec.yaml") -Raw
if ($Pubspec -match 'version:\s*([\d\.]+)') {
    $Version = $Matches[1]
} else {
    $Version = "1.0.0"
}

$AppName = "mini_app_qr"
$PackageName = "${AppName}_linux_v${Version}"

Write-Host "=========================================="
Write-Host " Empaquetado de Mini App QR (Linux)"
Write-Host "=========================================="
Write-Host "Version detectada: $Version"
Write-Host ""

# Verificar que existe el build
if (-not (Test-Path $BuildDir)) {
    Write-Error "No se encontro el build en: $BuildDir"
    Write-Host "Primero debes compilar la app ejecutando: .\build_linux.ps1"
    exit 1
}

# Crear directorio de salida
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Crear carpeta temporal
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
$PackageDir = Join-Path $TempDir $PackageName
New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null

# Copiar archivos del build
Write-Host "[1/3] Copiando archivos del build..."
Copy-Item -Path "$BuildDir\*" -Destination $PackageDir -Recurse -Force

# Copiar scripts de instalacion y kiosk
Write-Host "[2/3] Copiando scripts de instalacion..."
Copy-Item -Path "$ScriptsLinuxDir\install.sh" -Destination $PackageDir -Force
Copy-Item -Path "$ScriptsLinuxDir\uninstall.sh" -Destination $PackageDir -Force
Copy-Item -Path "$ScriptsLinuxDir\start_kiosk.sh" -Destination $PackageDir -Force
Copy-Item -Path "$ScriptsLinuxDir\exit_kiosk.sh" -Destination $PackageDir -Force

# Empaquetar como zip (compatible Windows/Linux)
Write-Host "[3/3] Generando archivo de distribucion..."
$ZipPath = Join-Path $OutputDir "${PackageName}.zip"
Compress-Archive -Path "$PackageDir\*" -DestinationPath $ZipPath -Force

# Limpiar
Remove-Item -Recurse -Force $TempDir

Write-Host ""
Write-Host "=========================================="
Write-Host " EMPAQUETADO COMPLETADO"
Write-Host "=========================================="
Write-Host "Archivo generado en:"
Write-Host "  $ZipPath"
Write-Host ""
Write-Host "Instrucciones de instalacion en el destino:"
Write-Host "  1. Transferir el .zip a la maquina Linux"
Write-Host "  2. Descomprimir: unzip ${PackageName}.zip"
Write-Host "  3. Entrar a la carpeta: cd $PackageName"
Write-Host "  4. Instalar: sudo ./install.sh"
Write-Host "=========================================="
