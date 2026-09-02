# Carga y administración de productos

Este documento describe cómo la aplicación obtiene, filtra, cachea y actualiza el catálogo de productos, incluyendo la lógica de los dos proveedores soportados.

---

## 1. Carga inicial

`HomeCubit` es el coordinador principal del catálogo que se presenta al usuario. Su constructor llama inmediatamente a `load()`, por lo que la carga inicial comienza al crear `HomePage` y su `BlocProvider`.

La carga sigue esta secuencia:

1. `HomeCubit` emite `HomeStatus.loading`.
2. Lee `AppSettings().merchantIds`.
3. Solicita en paralelo los productos de todos los merchants configurados.
4. Para cada merchant obtiene primero sus productos y después su información general.
5. Combina los resultados exitosos en un catálogo único.
6. Guarda el catálogo completo, sin filtros visuales, en `ProductCache`.
7. Aplica `ProductFilterConfig`.
8. Emite `HomeStatus.loaded`, coloca el carrusel en el índice cero y cambia la pantalla a `DisplayMode.attract`.
9. Registra la hora de la carga exitosa para determinar posteriormente si el catálogo está obsoleto.

```text
HomeCubit()
   ↓
load()
   ↓
MERCHANT_IDS
   ↓
┌──────────────┬──────────────┬──────────────┐
│ Merchant A   │ Merchant B   │ Merchant N   │  carga paralela
└──────┬───────┴──────┬───────┴──────┬───────┘
       └───────────────┼──────────────┘
                       ↓
             Catálogo combinado
                ↙             ↘
       ProductCache       Filtro visual
                              ↓
                         HomeState
```

---

## 2. Reintentos y fallos parciales

La carga completa permite un reintento adicional. Si el primer intento falla, espera dos segundos y vuelve a ejecutar la carga.

Dentro de cada intento, los merchants se procesan de forma independiente. `_loadSingleMerchant()` devuelve `null` si falla la carga de un comercio. Esto produce los siguientes comportamientos:

- Si falla un merchant pero al menos otro devuelve productos, la aplicación continúa con el catálogo parcial.
- Si ningún merchant devuelve productos, la carga se considera fallida.
- Si `MERCHANT_IDS` está vacío, la carga falla antes de llamar a las APIs.
- Después de agotar los intentos, `HomeCubit` emite `HomeStatus.error` con un mensaje para el usuario.

Aunque los merchants se cargan en paralelo, dentro de cada merchant la consulta de productos termina antes de solicitar su información general. Ambas operaciones reutilizan el mismo data source cacheado.

---

## 3. Catálogo combinado y origen del producto

Los productos de todos los merchants exitosos se agregan a una sola lista. Cada `Product` conserva `merchantId`, que permite:

- Determinar qué API debe validarlo antes del pago.
- Crear la orden con el merchant correcto.
- Resolver el nombre de la tienda mostrado o enviado en `menuData`.
- Agrupar productos por comercio en el endpoint interno `GET /products`.

`merchantIds` y `merchantNames` se mantienen como listas alineadas, y además existe el mapa `merchantsById` que asocia cada `merchantId` con su entidad `Merchant`. `HomeState.getMerchantNameForProduct()` busca primero en `merchantsById[merchantId]`; si no lo encuentra, ubica el `merchantId` en la lista y devuelve el nombre de la misma posición, y como último fallback usa el nombre general combinado.

---

## 4. Las dos cachés relacionadas con productos

El proyecto mantiene dos cachés diferentes, con responsabilidades distintas:

| Caché | Ubicación | Contenido y propósito |
| --- | --- | --- |
| Caché de data sources | `ProductRepositoryImpl` | Un `ProductDataSource` por `merchantId`. Evita volver a consultar la configuración del merchant en cada carga o polling. |
| Caché de catálogo | `ProductCache` | Productos sin filtrar, nombres e IDs de merchants. Permite que `AppServer` consulte el catálogo sin depender directamente de `HomeCubit`. |

La caché de data sources mantiene además el cliente Dio y la decisión de proveedor tomada la primera vez que se consulta el merchant. La caché de catálogo se reemplaza con listas no modificables después de cada carga exitosa.

---

## 5. Actualización del catálogo

El catálogo puede actualizarse de tres formas:

- Una llamada explícita a `HomeCubit.load()`.
- Un comando `ReloadProduct`, normalmente emitido después de modificar configuración o filtros.
- Un polling bajo demanda o forzado.

Durante un polling, el Cubit compara los campos relevantes de los productos frescos con los actuales. Si existen cambios, vuelve a aplicar los filtros y procura conservar seleccionado el mismo producto mediante su identificador. Si el producto activo desapareció, reinicia el carrusel en cero. El algoritmo detallado del polling se describe en la sección 7 de este documento.

### Diferencia clave entre `load()` y `_pollProducts()`

| Aspecto | `load()` | `_pollProducts()` |
| --- | --- | --- |
| Reinicio de carrito | Sí, vacía el carrito | No, reconcilia conservando cantidades |
| Modo visual final | `DisplayMode.attract` | Conserva el modo actual |
| Reintentos | Sí, hasta 2 intentos | Sí, usa `_loadWithRetry()` |
| Error | Emite `HomeStatus.error` | Fallo silencioso, conserva estado anterior |
| SnackBar | No | Sí, si hay cambios y está en modo `product` |
| Trigger | Inicio, `ReloadProduct` | `showProduct`, `ForceProductPoll` |

---

## 6. Fuentes de productos

La aplicación puede obtener catálogos desde dos APIs con estructuras diferentes. El resto del sistema trabaja con la misma interfaz `ProductDataSource`, por lo que no necesita saber cuál proveedor fue seleccionado.

### 6.1 Resolución de la configuración del merchant

La primera operación para un merchant no cacheado es:

```http
GET {BASE_URL}/merchants/{merchantId}
Authorization: Bearer {BEARER_TOKEN}
```

`MerchantConfigFactory` interpreta la respuesta y consulta `configuration.externalSystem`:

- `patio_service` selecciona el proveedor Legacy.
- Cualquier otro valor selecciona Ecosystem; el código lo identifica actualmente como `merchant_panel`.

La configuración resultante contiene el identificador, nombre, logotipo, tipo de facturación (`billingType`), URL base, token y, cuando corresponde, los identificadores externos requeridos por Ecosystem.

### 6.2 Proveedor Legacy

`LegacyProductDataSource` usa la API configurada en `BASE_URL` y el token de `BEARER_TOKEN`.

Para obtener el catálogo llama a:

```http
GET /v1/merchants/{merchantId}/products-categories
    ?include=products
    &filter=withProducts
```

La respuesta es una lista de categorías. El data source recorre cada categoría, extrae su lista `products` y aplana todas las listas en un único `List<Product>`.

El mapeo normaliza:

- `id` como identificador.
- `name` y `description` como texto, con cadena vacía como fallback.
- `price` y `oldPrice` como `double`.
- `urlImage` como dirección de la imagen.
- El `merchantId` recibido al construir el data source.

Para obtener un solo producto utiliza:

```http
GET /v1/merchants/{merchantId}/products/{productId}
```

Para obtener el comercio utiliza:

```http
GET /merchants/{merchantId}
```

### 6.3 Proveedor Ecosystem

`EcosystemProductDataSource` usa `ECOSYSTEM_BASE_URL` sin un sufijo final `/api` y autentica con `ECOSYSTEM_BEARER_TOKEN`.

Los IDs externos se obtienen de la respuesta de configuración:

| Campo externo | Uso |
| --- | --- |
| `companyExternalId` | `companyId` de la ruta Ecosystem. |
| `companyChannelExternalId` | `channelId` de la ruta. |
| `merchantExternalId` | `storeId` del query parameter. |

El catálogo se consulta mediante:

```http
GET /ecosystem/companies/{companyId}/channels/{channelId}/menu?storeId={storeId}
```

La respuesta incluye información del canal, tienda, moneda, totales y los ítems del menú. El data source descarta todo ítem cuyo `pccsStatus` sea exactamente `inactive`.

Para cada producto visible:

- Usa `idProduct` como identificador.
- Usa `effectivePrice` como precio actual.
- Conserva `basePrice` en `oldPrice` solamente cuando difiere del precio efectivo.
- Mapea nombre, descripción e imagen a la entidad común.
- Asigna el `merchantId` interno, no el `storeId` externo.

Ecosystem no dispone en este data source de una llamada especializada para un solo producto. `getProduct()` descarga el menú completo y busca el ID localmente. `getMerchantInfo()` vuelve a descargar el mismo menú y toma `store.nameStore` como nombre del comercio.

### 6.4 Contrato común

Ambas implementaciones cumplen estas tres operaciones:

```text
getProducts()                 → List<Product>
getProduct(productId)        → Product
getMerchantInfo()            → Merchant
```

Esta normalización permite que `ProductRepositoryImpl`, los casos de uso y los Cubits funcionen igual con ambos proveedores.

---

## 7. Polling de productos y reconciliación del carrito

No existe un timer periódico permanente para productos. El polling es bajo demanda al entrar al catálogo y solo ocurre cuando transcurrieron al menos `PRODUCT_POLLING_STALE_SECONDS`. Un valor menor o igual a cero lo deshabilita.

También puede forzarse sin considerar el umbral. La comparación considera longitud, orden, ID, merchant, nombre, precio, precio anterior, descripción e imagen. Sin cambios solo actualiza el timestamp interno; con cambios reemplaza estado y caché, conserva el producto activo por ID y mantiene el modo visual. Un error conserva silenciosamente el catálogo anterior.

Durante el polling, `HomeCubit` reconcilia el carrito con el catálogo fresco mediante `_reconcileCart()`:

- Si un producto del carrito desaparece del catálogo, se elimina del carrito y se genera un mensaje de aviso.
- Si un producto conservado cambió de precio, se mantiene la cantidad pero se genera un mensaje indicando que el precio fue actualizado.
- Las cantidades se conservan para los productos que siguen disponibles sin cambios de precio.

Los mensajes de sincronización se exponen en `HomeState.cartSyncMessage` y se muestran al usuario mediante un `SnackBar` cuando está en modo `product`. La revisión del mensaje (`cartSyncRevision`) permite distinguir avisos nuevos de los ya mostrados.

---

## 8. Filtros y visibilidad de productos

`ProductFilterConfig` decide qué merchants y productos aparecen en el carrusel. La configuración contiene cuatro elementos:

| Propiedad | Significado |
| --- | --- |
| `enabledMerchants` | Merchants permitidos. Vacío significa que todos están habilitados. |
| `hiddenProducts` | IDs ocultos cuando el modo es `blacklist`. |
| `pinnedProducts` | IDs fijados o permitidos con prioridad especial. |
| `filterMode` | Estrategia activa: `all`, `blacklist` o `whitelist`. |

### 8.1 Orden de evaluación

La visibilidad de un producto se calcula en este orden:

1. Si `enabledMerchants` no está vacío y el merchant no está incluido, el producto se oculta.
2. En modo `whitelist`, solo se muestran productos presentes en `pinnedProducts`.
3. Fuera de `whitelist`, un producto fijado se muestra incluso si también aparece en la blacklist.
4. En modo `blacklist`, se ocultan los IDs presentes en `hiddenProducts`.
5. En modo `all`, se muestra todo lo que haya superado la validación del merchant.

```text
¿Merchant habilitado?
   ├─ No → ocultar
   └─ Sí
       ├─ whitelist → mostrar solo si está pinned
       ├─ producto pinned → mostrar
       ├─ blacklist → mostrar si no está hidden
       └─ all → mostrar
```

### 8.2 Catálogo original frente a catálogo visible

`ProductCache.allProducts` conserva el resultado completo de las APIs. `HomeState.products` recibe únicamente los productos que pasan el filtro. Esta separación permite que los endpoints de administración informen productos ocultos y visibles sin tener que consultar nuevamente el backend.

`ProductCache.buildProductsResponse()` agrupa el catálogo por merchant e incluye por producto los campos `visible` y `pinned`. También calcula totales generales y por comercio.

### 8.3 Restablecimiento

`ProductFilterConfig.reset()`:

- Vacía merchants habilitados.
- Vacía productos ocultos.
- Vacía productos fijados.
- Restablece el modo a `all`.

Los endpoints que modifican y restablecen filtros, sus cuerpos JSON y su persistencia se documentan en [API.md](API.md).

---

## 9. Presentación visual del producto

### Imagen adaptativa

`AdaptiveProductImage` resuelve el tamaño real de la imagen remota antes de renderizarla. Si la diferencia de aspecto entre la imagen y su contenedor supera un umbral (`_maxCompatibleAspectDifference = 1.55`), el widget cambia a un layout protegido: fondo borroso escalado con `ImageFilter.blur`, una capa semitransparente y la imagen centrada con `BoxFit.contain`. Esto evita que productos con fotos muy verticales u horizontales sufran recortes excesivos con `BoxFit.cover`. Si la imagen es compatible, utiliza `BoxFit.cover` de forma convencional mediante `AppImage`.

### Indicadores del carrusel

`ProductCarousel` limita la cantidad de indicadores visibles a un máximo de 7. Cuando el catálogo supera ese tamaño, solo se muestra una ventana deslizante centrada en el producto activo. Esto mantiene la barra de indicadores compacta incluso con colecciones grandes.

---

## Referencias

- [Diagrama de selección de proveedor](diagrams/03-provider-selection.md)
- [Diagrama de arranque y carga inicial](diagrams/02-boot-sequence.md)
- [Diagrama de polling de productos](diagrams/08-product-polling.md)
- [Diagrama de filtros de productos](diagrams/16-product-filters.md)
- [Diagrama de flujo del carrito](diagrams/10-cart-flow.md)
- [API de productos y filtros](API.md)
- [Configuración de variables de entorno](CONFIGURATION.md)
