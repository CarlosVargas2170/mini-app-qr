# Ejecución y despliegue

## 1. Requisitos de desarrollo

- **Flutter** `3.44.3` (stable) — Dart `3.12.2` — DevTools `2.57.0`.
- Dependencias de escritorio de la plataforma.
- Archivo `.env` creado desde `.env_example`.
- Acceso de red a las APIs configuradas.

> Versión del SDK verificada en el entorno de desarrollo principal. La compilación de producción usa el mismo canal estable.

Comandos habituales:

```powershell
flutter pub get
flutter run -d windows
flutter analyze
flutter test
dart format lib test
```

La carpeta `test/` está versionada desde el commit `[TEST]-cart-checkout`. Las pruebas cubren modelos de datos, estados de Cubits, comportamiento del carrito y widgets de la interfaz.

## 2. Build Linux nativo

En una máquina Linux con Flutter desktop habilitado:

```bash
flutter config --enable-linux-desktop
flutter pub get
flutter build linux --release
```

El bundle queda en `build/linux/x64/release/bundle/`. Debe distribuirse completo, no solo el ejecutable.

## 3. Build Linux desde Windows con Docker

`build_linux.ps1`:

1. Construye `Dockerfile.linux` como imagen `mini_app_qr_linux_build`.
2. Crea un contenedor temporal.
3. Extrae `/app/build/linux/x64/release/bundle`.
4. Elimina el contenedor.

```powershell
./build_linux.ps1
```

El Dockerfile usa una imagen Flutter 3.27.0, instala GTK y herramientas de compilación, ejecuta `flutter create --platforms=linux .` y compila release.

## 4. Empaquetado

Desde PowerShell:

```powershell
./scripts/package_linux.ps1
```

Genera `dist/mini_app_qr_linux_v{version}.zip` e incluye el bundle y scripts de instalación/kiosco.

Desde Linux:

```bash
./scripts/package_linux.sh
```

Genera `.tar.gz` y `.zip`. La variante Linux copia `install.sh` y `uninstall.sh`; la variante PowerShell copia además `start_kiosk.sh` y `exit_kiosk.sh`. Conviene unificar esta diferencia antes de depender de ambos paquetes como equivalentes.

## 5. Instalación

Después de descomprimir el paquete:

```bash
chmod +x install.sh
sudo ./install.sh
```

El instalador:

- Exige root y verifica `./mini_app_qr`.
- Copia la aplicación a `/opt/mini_app_qr`.
- Crea `/usr/share/applications/mini_app_qr.desktop`.
- Configura autostart para `SUDO_USER` si está disponible.
- Apunta el autostart a `/opt/mini_app_qr/start_kiosk.sh`.

El icono configurado es `data/flutter_assets/assets/icon.png`; ese archivo no aparece en el árbol actual de assets, por lo que el acceso puede mostrarse sin icono.

## 6. Modo kiosco

`start_kiosk.sh`:

- Deshabilita atajos de GNOME mediante `gsettings`.
- Oculta el cursor si existe `unclutter`.
- Reinicia la aplicación si deja de ejecutarse.
- Intenta mantener la ventana al frente con `xdotool`.
- Revisa el estado cada dos segundos.

La salida controlada se solicita desde otra sesión, normalmente SSH:

```bash
/opt/mini_app_qr/exit_kiosk.sh
```

También puede crearse `/tmp/exit_mini_app_qr`. El loop restaura atajos, detiene la app, finaliza `unclutter` y elimina archivos temporales.

No se recomienda matar directamente el script salvo emergencia, porque podría dejar atajos modificados.

## 7. Autostart manual

```bash
./scripts/linux/setup_autostart.sh
```

Debe ejecutarse como el usuario cuya sesión gráfica iniciará la aplicación. Crea `~/.config/autostart/mini_app_qr.desktop`.

## 8. Desinstalación

```bash
sudo ./uninstall.sh
```

El script detiene/deshabilita un posible servicio systemd, elimina `/opt/mini_app_qr`, el acceso global y el archivo de servicio. No elimina explícitamente el `.desktop` de autostart creado en el home del usuario; debe retirarse manualmente si permanece.

## 9. Verificación posterior

- Confirmar que `.env` está incluido en el bundle y contiene configuración del entorno objetivo.
- Comprobar conectividad hacia APIs y resolución de certificados.
- Confirmar que `BASE_URL_VPN` pertenece a una interfaz local existente.
- Verificar que `PORT_VPN` no está ocupado y que el firewall aplica el alcance deseado.
- Probar audio y permisos del dispositivo.
- Probar inicio, salida y restauración de atajos del kiosco.
- Ejecutar un pago de prueba y validar cierre de orden.

## 10. Seguridad operativa

El bundle contiene `.env`; proteger permisos de `/opt/mini_app_qr`. El servidor HTTP interno no autentica solicitudes ni usa TLS. Debe exponerse únicamente en una VPN o segmento controlado. No registrar ni incluir tokens reales en paquetes distribuidos fuera del entorno autorizado.

## Referencias

- [Diagrama de despliegue Linux y modo kiosco](diagrams/14-linux-deployment.md)
- [Configuración de variables de entorno](CONFIGURATION.md)
- [Arquitectura general](ARCHITECTURE.md)
