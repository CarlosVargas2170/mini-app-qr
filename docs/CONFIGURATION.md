# Configuración de Mini App QR

## 1. Carga y prioridad

`main.dart` carga `.env` con `flutter_dotenv` y luego ejecuta `AppSettings().load()`. La implementación vigente llama directamente a `applyFallback()`: para cada campo usa el valor de `.env` y, si falta, un fallback compilado en `app_settings.dart`.

`ConfigStorage` puede leer y escribir `app_settings.json`, pero actualmente no participa en `AppSettings.load()` ni en `POST /config`. Por tanto, no hay persistencia dinámica efectiva.

## 2. Variables de entorno

| Variable | Formato | Fallback del código | Uso |
| --- | --- | --- | --- |
| `BASE_URL` | URL sin `/` final preferiblemente | API de tótem configurada en código | Configuración de merchants, productos Legacy, órdenes y pagos. |
| `BEARER_TOKEN` | String | Vacío | Autorización de `BASE_URL`. |
| `ECOSYSTEM_BASE_URL` | URL | API Ecosystem configurada en código | Menú del proveedor Ecosystem. Se elimina un sufijo `/api` si existe. |
| `ECOSYSTEM_BEARER_TOKEN` | String | Vacío | Autorización de Ecosystem. |
| `MERCHANT_IDS` | Enteros separados por coma | `53` | Merchants cargados en paralelo. |
| `PRODUCT_ID` | Entero | `457969` | ID compatible con configuración anterior; el catálogo actual maneja múltiples productos. |
| `BASE_URL_VPN` | IP o host enlazable | Dirección definida en el código | Interfaz donde escucha `AppServer`. Vacío o inválido termina usando `anyIPv4`. |
| `PORT_VPN` | Entero | `5050` | Puerto real del servidor local. |
| `NAME_MESERO` | Texto | `Robot Mesero` | Nombre de cliente por defecto en órdenes. |
| `QR_EXPIRATION_MINUTES` | Entero positivo | `3` | TTL de la caché de QR del panel embebido y texto informativo. |
| `PRODUCT_POLLING_STALE_SECONDS` | Entero | `60` | Antigüedad mínima para polling bajo demanda; `<= 0` lo deshabilita. |

Los tokens vacíos permiten arrancar, pero `AppSettings.isConfigured` exige `BASE_URL`, `BEARER_TOKEN`, al menos un merchant y `PRODUCT_ID != 0`. El flujo principal no consulta actualmente `isConfigured` antes de iniciar.

## 3. Plantilla segura

`.env_example` debe contener nombres y ejemplos no sensibles:

```env
BASE_URL=https://api.example.com/api
BEARER_TOKEN=
ECOSYSTEM_BASE_URL=https://merchant-api.example.com
ECOSYSTEM_BEARER_TOKEN=
MERCHANT_IDS=53,54
PRODUCT_ID=1000
BASE_URL_VPN=100.x.x.x
PORT_VPN=5050
NAME_MESERO=Robot Mesero
QR_EXPIRATION_MINUTES=3
PRODUCT_POLLING_STALE_SECONDS=60
```

`.env` está declarado como asset en `pubspec.yaml`: sus valores se incluyen en el bundle compilado. No debe considerarse un almacén secreto fuerte. Si los tokens son sensibles, conviene entregar credenciales de corta duración o usar almacenamiento/inyectado de secretos apropiado para el entorno.

## 4. Configuración dinámica por HTTP

`POST /config` puede modificar en memoria:

- `baseUrl` y `bearerToken`: requieren reinicio porque Dio ya fue construido.
- `merchantId`, `merchantIds` y `productId`: emiten `ReloadProduct`.
- `baseUrlVpn` y `portVpn`: requieren reinicio porque el socket ya está enlazado.

No permite modificar Ecosystem, nombre, expiración ni staleness. Tampoco escribe `.env` ni `app_settings.json`.

El repositorio de productos cachea un data source por merchant. Incluso una recarga no invalida esa caché; cambios de proveedor, URL o IDs externos requieren reconstruir el proceso o implementar invalidación explícita.

## 5. Filtros dinámicos

Los filtros viven en `AppSettings.filterConfig`, exclusivamente en memoria. Al iniciar siempre se crea modo `all` con conjuntos vacíos. `POST /products/filter` puede modificar merchants habilitados, productos ocultos/fijados y modo. Para reflejarlo inmediatamente en el carrusel debe enviarse `reload: true`.

## 6. Seguridad

- Nunca versionar `.env`, tokens o credenciales.
- No registrar cuerpos o encabezados que contengan secretos.
- `GET /config` expone actualmente `bearerToken`; debería enmascararse o eliminarse antes de exponer el servidor fuera de una red confiable.
- Restringir `BASE_URL_VPN` a una interfaz privada y aplicar firewall.
- El servidor interno carece de autenticación y usa CORS `*`.
- Rotar cualquier credencial que haya sido publicada accidentalmente en Git, incluso si después se elimina del historial visible.

## 7. Archivos versionados

Se recomienda versionar `.env_example` y este documento. `.env` debe permanecer en `.gitignore`. Los valores públicos de ejemplo deben ser ficticios o estar aprobados explícitamente para publicación.
