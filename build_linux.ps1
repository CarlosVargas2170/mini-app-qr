# Build Flutter Linux desde Windows usando Docker
$ErrorActionPreference = "Stop"

$ImageName = "mini_app_qr_linux_build"
$ContainerName = "mini_app_qr_extract"

Write-Host "=== Construyendo imagen Docker para compilacion Linux ==="
docker build -f Dockerfile.linux -t $ImageName .

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error al construir la imagen Docker."
    exit 1
}

Write-Host "=== Extrayendo ejecutable del contenedor ==="
docker create --name $ContainerName $ImageName | Out-Null

$OutputDir = ".\build\linux\x64\release\bundle"
if (Test-Path $OutputDir) {
    Remove-Item -Recurse -Force $OutputDir
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

docker cp "$($ContainerName):/app/build/linux/x64/release/bundle/." $OutputDir
docker rm $ContainerName | Out-Null

Write-Host ""
Write-Host "=========================================="
Write-Host "BUILD COMPLETADO"
Write-Host "=========================================="
Write-Host "Ejecutable Linux generado en:"
Write-Host "  $OutputDir\mini_app_qr"
Write-Host ""
Write-Host "Para distribuir, empaqueta toda la carpeta 'bundle'."
Write-Host "=========================================="
