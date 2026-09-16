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

`merchantIds` y `merchantNames` se mantienen como listas alineadas. `HomeState.getMerchantNameForProduct()` busca la posición del `merchantId` y devuelve el nombre ubicado en la misma posición. Si no encuentra una coincidencia, usa el nombre general combinado como fallback.

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

## 6.5 Toppings (modificadores de producto)

`Product.toppings` es una lista opcional de `Topping` (grupo de opciones: `id`, `name`, `minLimit`, `maxLimit`, `type`, `subToppings`). `Product.hasToppings` decide si el selector de personalización aparece para ese producto; un producto sin toppings configurados en el backend simplemente no muestra la opción, sin distinción visible entre proveedores.

`ToppingType` tiene tres valores (`checkbox`, `radio`, `increment`), con nombres iguales al string que envían ambos proveedores.

**Legacy** entrega el `type` de cada grupo ya resuelto dentro del mismo JSON de `products-categories` (campo `toppings` por producto). `LegacyProductDataSource` lo mapea directamente con `mapLegacyToppings()` (`lib/data/mappers/topping_mapper.dart`), sin necesidad de inferencia.

**Ecosystem** entrega `toppingGroups` por item del menú, sin el tipo resuelto. `MenuItemDto.toToppings()` (vía `ToppingGroupDto.toTopping()`) infiere el tipo:

- `groupType == 'extra'` → `increment` (permite repetir la misma opción, ej. "extra queso x3").
- `maxAllowed == 1` → `radio`.
- cualquier otro caso → `checkbox`.

En ambos proveedores se descartan grupos ocultos (`isHidden`) y grupos que se quedan sin sub-toppings visibles tras filtrar.

El carrito ya no es un mapa `producto → cantidad`: `HomeState.cartLines` es una lista de `CartItem` (producto + toppings elegidos + cantidad + precio), lo que permite que el mismo producto aparezca en varias líneas con configuraciones distintas. `CartItem.unitPriceFor()` calcula el precio de una unidad como precio base + subtoppings elegidos (`checkbox`/`radio`, cuentan una vez) + subtoppings de grupos `increment` (cuentan por la cantidad elegida, buscando su precio en `product.toppings` porque `extraQuantities` solo guarda ids y cantidades).

La configuración de un producto con toppings se arma en una mini ventana anclada (`ProductToppingsButton` + `ProductConfigCubit`, en `lib/presentation/widgets/product_toppings_modal.dart` y `lib/presentation/bloc/`), no en un `showModalBottomSheet` a pantalla completa: usa el mismo mecanismo que `FloatingCart` (`LayerLink` + `CompositedTransformFollower` + `OverlayEntry`) para quedar acotada a un tamaño fijo cerca del botón que la abre (junto al carrito), en vez de invadir la parte de la pantalla que en el hardware del tótem no es visible/táctil por debajo de la card del producto. Esa mini ventana replica la validación por grupo: `radio` exige una selección si `minLimit > 0`; `checkbox` exige al menos `minLimit` opciones (el máximo se previene en la UI); `increment` exige que la suma de cantidades elegidas esté entre `minLimit` y `maxLimit`. `HomeCubit.addConfiguredItem()` fusiona la nueva línea con una existente del mismo producto solo si la configuración es idéntica (`CartItem.configurationSignature`); si no, crea una línea nueva.

Un producto con toppings no admite el "+/-" simple del carrusel (`_buildQuantitySelector` no muestra nada en ese caso): agregarlo siempre pasa por el botón de personalizar junto al carrito, para no crear una línea sin configurar cuando el producto exige elegir algo.

---

## 7. Polling de productos y reconciliación del carrito

No existe un timer periódico permanente para productos. El polling es bajo demanda al entrar al catálogo y solo ocurre cuando transcurrieron al menos `PRODUCT_POLLING_STALE_SECONDS`. Un valor menor o igual a cero lo deshabilita.

También puede forzarse sin considerar el umbral. La comparación considera longitud, orden, ID, merchant, nombre, precio, precio anterior, descripción e imagen. Sin cambios solo actualiza el timestamp interno; con cambios reemplaza estado y caché, conserva el producto activo por ID y mantiene el modo visual. Un error conserva silenciosamente el catálogo anterior.

Durante el polling, `HomeCubit` reconcilia el carrito con el catálogo fresco mediante `_reconcileCart()`, ahora operando sobre líneas (`CartItem`) en vez de un mapa de cantidades:

- Si el producto base de una línea desaparece del catálogo, la línea completa se elimina y se genera un mensaje de aviso.
- Si el producto sigue existiendo, se recalcula el precio de la línea con el precio base fresco y, para cada topping/sub-topping seleccionado, con su precio fresco (si el id ya no existe en `freshProduct.toppings`, ese sub-topping o grupo se quita de la línea en silencio). Un cambio de precio resultante genera el mismo aviso que hoy existe para productos sin toppings.
- No se re-valida `minLimit`/`maxLimit` durante el polling (mismo alcance que ya tenía la reconciliación antes de esta funcionalidad: solo existencia y precio).
- Las cantidades se conservan para las líneas que siguen siendo válidas.

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
