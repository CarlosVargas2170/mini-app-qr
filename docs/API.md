# API de Mini App QR

Este documento describe los contratos observados en el código. La carpeta `remote-control/` queda fuera de alcance.

## 1. Servidor HTTP interno

La aplicación escucha en `http://{BASE_URL_VPN}:{PORT_VPN}`. Todas las respuestas son JSON. Se permite CORS para cualquier origen y los `OPTIONS` responden `204`. No hay autenticación interna.

### 1.1 Resumen de endpoints

| Método | Ruta | Acción |
| --- | --- | --- |
| POST | `/audio/play` | Reproduce un asset mediante body JSON. |
| POST | `/audio/stop` | Detiene el audio. |
| POST | `/play-audio` | Reproduce audio mediante query parameters. |
| POST | `/play-question` | Muestra primer producto y reproduce pregunta. |
| POST | `/play-thanks` | Reproduce agradecimiento. |
| POST | `/play-buy` | Reproduce invitación de compra. |
| POST | `/play-order` | Reproduce aviso de orden. |
| POST | `/play-attention` | Reproduce mensaje de atención. |
| POST | `/play-collect-tray` | Reproduce aviso de bandeja. |
| POST | `/play-coffee` | Reproduce aviso de café listo. |
| POST | `/proximity/near` | Muestra atracción. |
| POST | `/greet` | Muestra primer producto y reproduce saludo. |
| POST | `/greet/audio` | Muestra primer producto y reproduce un audio indicado. |
| POST | `/product` | Muestra productos sin audio. |
| POST | `/cancel-payment` | Cancela el pago visible. |
| POST | `/proximity/away` | Muestra reposo. |
| POST | `/carrusel/product` | Muestra atracción; nombre conservado por compatibilidad. |
| POST | `/payment/start-polling` | Emite inicio manual del polling. |
| POST | `/payment/stop-polling` | Emite detención del polling. |
| GET | `/payment/polling-status` | Consulta pago visible y contador. |
| POST | `/payment/reset-counter` | Reinicia contador en memoria. |
| GET | `/config` | Devuelve configuración vigente. |
| POST | `/config` | Modifica campos en memoria. |
| GET | `/products` | Devuelve catálogo cacheado y visibilidad. |
| POST | `/products/filter` | Modifica filtros en memoria. |
| POST | `/products/reload` | Dispara carga completa. |
| POST | `/products/polling/force` | Fuerza polling de productos. |
| GET | `/products/polling/status` | Devuelve el umbral de staleness. |
| POST | `/attract/set` | Selecciona y muestra un GIF. |
| GET | `/attract/current` | Devuelve el GIF configurado. |

Una combinación no reconocida responde `404` con `{"success":false,"message":"Endpoint no encontrado"}`.

## 2. Audio

### `POST /audio/play`

```json
{
  "asset": "audio/question_coffe.wav",
  "volume": 1.0,
  "force": false,
  "displayText": "¿Deseas un café?",
  "showOverlay": true
}
```

`asset` es obligatorio. Los demás campos son opcionales. Responde `200` incluso cuando el cooldown omite el audio; `played` informa el resultado. JSON inválido o asset ausente produce `400`.

`asset` también puede ser una URL de Cloudinary de un audio subido desde el panel (ver [Archivos de Cloudinary](#archivos-de-cloudinary)).

### `POST /play-audio`

Query parameters: `asset` obligatorio; `volume` (default `1.0`), `force` (`true`/`false`) y `displayText` opcionales. Esta variante no expone `showOverlay` y usa el valor predeterminado `true`. Acepta URLs de Cloudinary igual que `/audio/play`.

### Archivos de Cloudinary

`/audio/play`, `/play-audio`, `/greet/audio` (`asset`) y `/attract/set` (`url`) aceptan archivos subidos desde el panel a Cloudinary. El robot los descarga una vez a una caché en disco y los reproduce desde ahí, por lo que siguen sonando sin internet.

Como este servidor no autentica solicitudes, solo se aceptan URLs `https://res.cloudinary.com/<cloud>/<image|video>/upload/...` del cloud configurado (`zrwcfuqw` por defecto; `CLOUDINARY_CLOUD_NAME` en `.env` lo cambia), sin query ni credenciales, con extensión `.wav`, `.mp3`, `.ogg`, `.m4a` o `.aac` para audio y `.gif` para imágenes. No se siguen redirecciones. Máximos: 20 MB (audio) y 25 MB (GIF).

| Caso | Respuesta |
|---|---|
| URL no permitida (otro servidor, extensión, cloud…) | `400` con `success:false` y `message` |
| Cloudinary no responde, responde un error, o el disco falla | `502` con `success:false` y `message` |
| Archivo ya en caché | `200`, sin descargar |

La primera reproducción de un archivo nuevo espera a la descarga. La caché está en `~/.local/share/mini_app_qr/media_cache/` (Linux; `%LOCALAPPDATA%\mini_app_qr\media_cache\` en Windows), fuera de `build/` para que sobreviva a recompilar y a actualizar el bundle. Si esa carpeta no se puede crear, usa una junto al ejecutable y, en último caso, la carpeta temporal. Para vaciarla basta borrar la carpeta: los archivos se vuelven a descargar al usarse.

### Endpoints de audio predefinido

`/play-question`, `/play-thanks`, `/play-buy`, `/play-order`, `/play-attention`, `/play-collect-tray` y `/play-coffee` no necesitan body. Devuelven `success`, `played` y `message`. `/play-question` también emite `ShowProductResetCarousel`.

`POST /audio/stop` devuelve `{"success":true,"message":"Audio detenido"}`.

## 3. Control de interfaz

- `/proximity/near` → `ShowAttract`.
- `/greet` → `ShowProductResetCarousel` y audio de pregunta.
- `/greet/audio?asset=audio/saludo.wav` → `ShowProductResetCarousel` y el audio indicado.
- `/product` → `ShowProduct`.
- `/cancel-payment` → `CancelPayment`.
- `/proximity/away` → `ShowIdle`.
- `/carrusel/product` → `ShowAttract`.

### `POST /greet/audio`

Muestra el carrusel, lo reinicia al primer producto y reproduce un asset de
`assets/audio/`:

```text
POST /greet/audio?asset=audio/kiky/Hola_deseas_un_Brown.wav
```

Parámetros opcionales: `force=true`, `displayText=Hola` y
`showOverlay=false`. También acepta rutas con prefijo `assets/audio/`, que se
normalizan antes de reproducirse. Una ruta ausente, externa, con `..` o con
extensión distinta de `.wav`, `.mp3`, `.m4a` u `.ogg` responde `400`. Un asset
con ruta válida que no exista dentro de la aplicación responde `404`.

Las respuestas confirman que el comando fue emitido, no que Flutter ya terminó de procesarlo.

## 4. Pago y contador

`POST /payment/start-polling` y `POST /payment/stop-polling` publican comandos broadcast. Los consume `ProductQrPanelWrapper`; `HomePage` por sí mismo no los ejecuta.

`GET /payment/polling-status` devuelve:

```json
{
  "success": true,
  "isPolling": true,
  "phase": "polling",
  "productId": 1,
  "merchantId": 53,
  "orderId": 100,
  "amount": 20.0,
  "productName": "Producto",
  "updatedAt": "2026-01-01T12:00:00.000",
  "label": "Polling activo",
  "counter": {
    "totalSales": 1,
    "totalAmount": 20.0,
    "recent": [],
    "byProduct": []
  }
}
```

Las fases posibles son `idle`, `waiting`, `polling`, `success` y `failed`. `POST /payment/reset-counter` pone totales y listas en cero; no afecta órdenes ni polling.

## 5. Configuración

`GET /config` devuelve `baseUrl`, `merchantId`, `merchantIds`, `productId`, `baseUrlVpn` y `portVpn`. Las credenciales, incluido `bearerToken`, se omiten deliberadamente de la respuesta.

`POST /config` acepta cualquier subconjunto:

```json
{
  "baseUrl": "https://api.example.com/api",
  "bearerToken": "token",
  "merchantIds": [53, 54],
  "productId": 1,
  "baseUrlVpn": "100.x.x.x",
  "portVpn": 5050
}
```

`merchantId` singular se conserva por compatibilidad y se convierte a una lista de un elemento. Merchant y producto generan recarga inmediata. URL, token, host y puerto devuelven `needsRestart: true`. Los cambios no se persisten.

## 6. Productos y filtros

`GET /products` usa `ProductCache`. Antes de la carga responde `200`, `data: null` y `cacheLoaded: false`. Después devuelve merchants agrupados, productos, visibilidad, fijados y totales.

`POST /products/filter` acepta:

```json
{
  "merchants": {"53": {"enabled": true}},
  "products": {
    "457969": {"visible": false},
    "457970": {"visible": true, "pinned": true}
  },
  "filterMode": "blacklist",
  "reload": true,
  "reset": false
}
```

Modos válidos: `all`, `blacklist`, `whitelist`. `reset: true` limpia filtros. `reload: true` emite una carga completa; sin esa bandera la memoria cambia pero el `HomeState` visible no se recalcula inmediatamente.

`POST /products/reload` emite `ReloadProduct`. `POST /products/polling/force` emite `ForceProductPoll`. Ambos responden antes de finalizar la operación asíncrona. `GET /products/polling/status` solo devuelve `data.staleSeconds`; no expone la hora ni resultado del último poll.

## 7. GIF de atracción

`POST /attract/set` acepta `{"gif":"normal"}` y mapea directamente a `assets/images/normal.gif`. Si falta, usa `attract`. No valida previamente que el asset exista.

Con `{"gif":"wink","url":"https://res.cloudinary.com/..../wink.gif"}` descarga el GIF a la caché y lo muestra desde ahí (ver [Archivos de Cloudinary](#archivos-de-cloudinary)). La descarga ocurre antes de cambiar la pantalla: si falla, responde `400`/`502` y el GIF actual no cambia. La respuesta incluye `url`.

`GET /attract/current` devuelve `gif` y `assetPath` desde el valor global vigente. Si el GIF viene de Cloudinary, `assetPath` es `null` y se devuelve `url`.

## 8. APIs externas

### Configuración del merchant

`GET {BASE_URL}/merchants/{merchantId}` decide proveedor y aporta IDs externos. Usa `BEARER_TOKEN`.

### Productos Legacy

- `GET /v1/merchants/{merchantId}/products-categories?include=products&filter=withProducts`
- `GET /v1/merchants/{merchantId}/products/{productId}`
- `GET /merchants/{merchantId}`

### Productos Ecosystem

`GET {ECOSYSTEM_BASE_URL}/ecosystem/companies/{companyId}/channels/{channelId}/menu?storeId={storeId}`. Se utiliza tanto para catálogo como para buscar un producto o resolver el nombre de tienda.

### Órdenes y QR

`POST /orders/create-pending` recibe carrito, método, lugar de consumo, referencia, cliente y, opcionalmente, datos de facturación (`nit` y `businessName`). El carrito contiene `metadataMerchant`, `items`, `subtotal`, `tax: 0.0` y `total`. Cada ítem del carrito incluye `id`, `name`, `quantity`, `unitPrice` y `totalPrice`. El agrupamiento prioriza el `id` del producto; si no está disponible, usa el nombre en minúsculas como clave de agrupación.

`POST /payments/qr/generate-payment`:

```json
{"amount": 20.0, "merchantId": 53, "orderId": 100}
```

`GET /payments/qr/status/{merchantId}/{orderId}` devuelve un campo `status`.

`PUT /orders/{orderId}` acepta únicamente campos no vacíos entre `customerName`, `nit`, `businessName` y `phoneNumber`.

`POST /orders/complete/{orderId}` marca la orden como completada.

Todas estas rutas usan el Dio basado en `BASE_URL`, timeout de conexión/respuesta de 20 segundos y `Authorization: Bearer {BEARER_TOKEN}`.
