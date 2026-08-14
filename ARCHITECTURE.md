# Arquitectura de Mini App QR

## 1. Introducción y propósito

Mini App QR es una aplicación Flutter orientada a ejecutarse como una interfaz de autoservicio o tótem en pantalla completa. Su función principal es mostrar un catálogo de productos pertenecientes a uno o varios comercios, permitir que el usuario seleccione un producto y gestionar su pago mediante un código QR.

Además de la interfaz gráfica, la aplicación levanta un servidor HTTP local. Este servidor permite que otro sistema —por ejemplo, un robot, un controlador físico o un servicio conectado por VPN— envíe comandos para cambiar lo que aparece en pantalla, reproducir audios, actualizar la configuración, consultar productos y controlar el seguimiento de un pago.

En términos generales, la aplicación realiza estas tareas:

- Carga su configuración desde variables de entorno.
- Consulta la configuración y el catálogo de uno o varios merchants.
- Adapta la obtención de productos a dos proveedores de datos: Legacy y Ecosystem.
- Presenta una pantalla de atracción, un carrusel de productos y el flujo de pago.
- Crea una orden pendiente y solicita al backend un QR de pago.
- Consulta periódicamente el estado del pago y completa la orden cuando se confirma.
- Reproduce mensajes de audio asociados a interacciones y resultados.
- Expone una API HTTP local para controlar la aplicación desde otro proceso o dispositivo.

### 1.1 Alcance de esta documentación

Este documento describe el código vigente ubicado en `lib/`, los recursos declarados en `assets/`, la configuración de Flutter y los scripts de ejecución y empaquetado del proyecto.

La carpeta `remote-control/` no forma parte del análisis porque contiene una implementación desactualizada. Las referencias históricas a un "remote control" que todavía aparecen en comentarios del código se entienden únicamente como referencias al consumidor del servidor HTTP local, no como documentación de esa carpeta.

## 2. Tecnologías y dependencias principales

El proyecto usa Dart 3 y Flutter. Aunque Flutter permite compilar para varias plataformas, la configuración actual está especialmente orientada a una aplicación de escritorio ejecutada en pantalla completa y a su distribución en Linux.

| Tecnología o paquete | Responsabilidad |
| --- | --- |
| Flutter | Construcción de la interfaz, navegación, widgets, temas y acceso al ciclo de vida de la aplicación. |
| Dart | Lenguaje de implementación y soporte de asincronía, streams, timers y servidor HTTP. |
| `flutter_bloc` | Implementación de Cubits y conexión de sus estados con la interfaz. |
| `equatable` | Comparación por valor de estados y otros objetos, evitando actualizaciones innecesarias. |
| `dio` | Cliente HTTP usado para consumir las APIs externas. |
| `flutter_dotenv` | Lectura del archivo `.env` durante el arranque. |
| `audioplayers` | Reproducción y control de los recursos de audio. |
| `window_manager` | Configuración de la ventana de escritorio en pantalla completa y sin barra de título. |
| `carousel_slider` | Presentación y navegación del carrusel de productos. |
| `cached_network_image` | Descarga y caché de imágenes remotas de productos. |

Para desarrollo se usan `flutter_test` y `flutter_lints`. El primero proporciona las herramientas de pruebas unitarias y de widgets; el segundo aplica las reglas estáticas definidas por el proyecto.

## 3. Vista general de la arquitectura

La aplicación sigue una arquitectura por capas inspirada en Clean Architecture. El objetivo es separar las reglas del negocio, el acceso a datos, la gestión del estado visual y los servicios compartidos.

```text
┌─────────────────────────────────────────────────────────────┐
│ Presentation                                                │
│ Pages, widgets, HomeCubit y QrPaymentCubit                  │
└───────────────────────────┬─────────────────────────────────┘
                            │ ejecuta
┌───────────────────────────▼─────────────────────────────────┐
│ Domain                                                      │
│ Entidades, contratos de repositorio y casos de uso          │
└───────────────────────────┬─────────────────────────────────┘
                            │ implementado por
┌───────────────────────────▼─────────────────────────────────┐
│ Data                                                        │
│ Repositorios, data sources, DTOs, mapeos y factories        │
└───────────────────────────┬─────────────────────────────────┘
                            │ consume
┌───────────────────────────▼─────────────────────────────────┐
│ APIs externas                                               │
│ Configuración de merchants, productos, órdenes y pagos QR   │
└─────────────────────────────────────────────────────────────┘

Core atraviesa la composición de la aplicación:
configuración, inyección, servidor HTTP, audio, cachés y bus de comandos.
```

### 3.1 Capa `presentation`

Contiene todo lo relacionado con la experiencia visible y su estado:

- Las páginas principales, como `HomePage` y `QrPaymentPage`.
- Widgets del carrusel, tarjetas de producto, QR, resultados, overlays de audio, selector de cantidad y carrito flotante.
- `HomeCubit`, encargado del catálogo y de los modos visuales de la pantalla principal.
- `QrPaymentCubit`, encargado del ciclo de vida del pago.
- Los estados inmutables emitidos por ambos Cubits.

La presentación no realiza solicitudes HTTP directamente. Solicita operaciones a través de casos de uso del dominio.

### 3.2 Capa `domain`

Representa las reglas y conceptos centrales del negocio sin depender de Flutter ni de Dio. Contiene:

- Las entidades `Product`, `Merchant`, `Order` y `OrderStatus`.
- Los contratos `ProductRepository` y `QrPaymentRepository`.
- Casos de uso pequeños que representan acciones concretas, como obtener productos, iniciar un pago o completar una orden.

Los contratos definen qué necesita la aplicación, pero no cómo se obtiene. Esta separación permite cambiar un endpoint o proveedor sin modificar los Cubits ni las entidades.

### 3.3 Capa `data`

Implementa los contratos definidos en el dominio. Sus responsabilidades son:

- Consumir APIs externas con Dio.
- Construir los cuerpos de las peticiones.
- Interpretar las respuestas mediante DTOs.
- Convertir DTOs y JSON en entidades del dominio.
- Elegir el proveedor de productos adecuado para cada merchant.
- Traducir errores técnicos a excepciones manejables por las capas superiores.

### 3.4 Capa `core`

Agrupa capacidades compartidas por toda la aplicación:

- Configuración global y variables de entorno.
- Inyección manual de dependencias.
- Tema y colores.
- Servidor HTTP local.
- Reproducción y notificaciones de audio.
- Caché compartida de productos.
- Contador de pagos.
- Estado global del polling de pagos.
- Bus de comandos que conecta el servidor local con la interfaz.

`core` no es una capa de negocio. Es el conjunto de piezas de infraestructura y configuración necesarias para conectar las demás capas.

### 3.5 Flujo típico entre capas

Una operación iniciada desde la interfaz sigue normalmente este recorrido:

```text
Interacción o comando externo
        ↓
Página o widget
        ↓
Cubit
        ↓
Caso de uso
        ↓
Contrato de repositorio
        ↓
Implementación del repositorio
        ↓
Data source y Dio
        ↓
API externa
```

La respuesta vuelve en sentido contrario. El repositorio transforma los datos en entidades, el Cubit emite un estado nuevo y la interfaz se reconstruye a partir de ese estado.

## 4. Estructura del proyecto

```text
mini-app-qr/
├── lib/
│   ├── core/
│   │   ├── config/
│   │   ├── constants/
│   │   ├── di/
│   │   ├── services/
│   │   └── ui/
│   ├── data/
│   │   ├── datasources/
│   │   ├── factories/
│   │   ├── models/
│   │   └── repositories/
│   ├── domain/
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   ├── presentation/
│   │   ├── bloc/
│   │   ├── pages/
│   │   └── widgets/
│   └── main.dart
├── assets/
│   ├── audio/
│   ├── images/
│   └── videos/
├── scripts/
│   └── linux/
├── pubspec.yaml
├── .env_example
└── Dockerfile.linux
```

### 4.1 `lib/core`

- `config/`: carga y representa la configuración global, la selección de proveedores y los filtros de productos.
- `constants/`: centraliza rutas o identificadores constantes, principalmente mensajes de audio.
- `di/`: compone las dependencias de la aplicación mediante un service locator manual.
- `services/`: implementa el servidor local, audio, cachés, contadores, estado de polling y comunicación por comandos.
- `ui/`: contiene elementos visuales compartidos, como la paleta de colores.

### 4.2 `lib/data`

- `datasources/`: encapsula las llamadas HTTP de productos y pagos.
- `factories/`: selecciona dinámicamente el data source de productos.
- `models/`: contiene DTOs para solicitudes y respuestas externas.
- `repositories/`: implementa los contratos de dominio y coordina data sources y mapeos.

### 4.3 `lib/domain`

- `entities/`: modelos independientes de infraestructura.
- `repositories/`: interfaces que describen las capacidades requeridas.
- `usecases/`: operaciones que los Cubits pueden ejecutar sin conocer detalles de red.

### 4.4 `lib/presentation`

- `bloc/`: Cubits y estados de la pantalla principal y del pago QR.
- `pages/`: pantallas que organizan los flujos completos.
- `widgets/`: componentes visuales reutilizables y especializados, incluyendo carrusel, tarjetas, selector de cantidad (`ProductQuantitySelector`) y carrito flotante (`FloatingCart`).

### 4.5 Recursos y scripts

Los audios e imágenes están registrados en `pubspec.yaml` como recursos de Flutter. La aplicación utiliza imágenes animadas para sus distintos modos visuales y audios para saludos, instrucciones, notificaciones y confirmaciones.

Aunque existe `assets/videos/`, en el `pubspec.yaml` vigente solo se registran `.env`, `assets/audio/` y `assets/images/`. Por lo tanto, cualquier video que se cargue como asset de Flutter debe registrarse antes de poder utilizarse en una compilación.

Los scripts de `scripts/linux/` cubren instalación, desinstalación, entrada y salida del modo kiosco e inicio automático. Los detalles operativos se documentarán en la sección de ejecución y despliegue.

## 5. Inicialización de la aplicación

El punto de entrada es `lib/main.dart`. La secuencia de arranque es importante porque las dependencias HTTP necesitan que la configuración ya esté disponible.

### 5.1 Secuencia de arranque

1. `WidgetsFlutterBinding.ensureInitialized()` prepara Flutter antes de ejecutar operaciones asincrónicas.
2. `window_manager` se inicializa para controlar la ventana nativa.
3. La ventana se configura a pantalla completa, centrada y sin barra de título.
4. Se restringe la orientación preferida a los modos verticales compatibles.
5. `flutter_dotenv` carga el archivo `.env` empaquetado como asset.
6. `AppSettings().load()` aplica la configuración disponible y sus valores fallback.
7. `sl.init()` construye clientes HTTP, data sources, repositorios y casos de uso.
8. Se crea e inicia `AppServer`, el servidor HTTP local.
9. `runApp()` construye `MyApp` y muestra `HomePage`.

```text
main()
  ├─ Inicializar Flutter
  ├─ Configurar ventana
  ├─ Cargar .env
  ├─ Cargar AppSettings
  ├─ Construir dependencias
  ├─ Iniciar AppServer
  └─ Ejecutar MyApp → HomePage
```

### 5.2 Configuración de escritorio

La ventana usa un tamaño inicial de 800 × 600, pero se abre en pantalla completa. La barra de título queda oculta. Esta configuración favorece el uso en un tótem o equipo dedicado, donde la aplicación debe ocupar toda la pantalla.

### 5.3 Inicio del servidor local

`main.dart` construye `AppServer(port: 8080)`, pero el servidor vigente enlaza el socket usando `AppSettings().portVpn`. En consecuencia, el argumento `8080` no determina actualmente el puerto real; prevalece `PORT_VPN`, cuyo fallback es `5050`.

El inicio del servidor no se espera con `await`. Se ejecuta concurrentemente mientras Flutter continúa construyendo la interfaz. Si el socket no puede abrirse, el error se registra, pero no impide que la aplicación gráfica arranque.

### 5.4 Aplicación raíz

`MyApp` configura un `MaterialApp` con Material 3, tema oscuro, colores personalizados y sin la etiqueta de depuración. `HomePage` es la pantalla raíz y desde ella se administran el catálogo, los modos visuales y el acceso al pago.

## 6. Inyección de dependencias

El proyecto usa un service locator manual definido en `lib/core/di/service_locator.dart`. Es un singleton global accesible mediante `sl`.

### 6.1 Dependencias de larga duración

Durante `sl.init()` se crean una sola vez:

- Un cliente Dio para órdenes y pagos, configurado con `BASE_URL` y `BEARER_TOKEN`.
- `QrPaymentRemoteDataSource`.
- `ProductDataSourceFactory`.
- Las implementaciones de `ProductRepository` y `QrPaymentRepository`.
- Todos los casos de uso de productos, merchants y pagos.

El cliente Dio establece tiempos máximos de conexión y respuesta de 20 segundos. También agrega los encabezados `Authorization: Bearer ...` y `Content-Type: application/json`.

### 6.2 Dependencias creadas bajo demanda

Los Cubits no se mantienen como singletons:

- `sl.homeCubit()` crea un `HomeCubit` nuevo.
- `sl.qrPaymentCubit()` crea un `QrPaymentCubit` nuevo.

Esto evita compartir accidentalmente timers y estado visual entre pantallas o flujos de pago distintos. Cada Cubit recibe casos de uso ya construidos, por lo que no conoce Dio, URLs ni DTOs.

### 6.3 Selección dinámica del proveedor de productos

`ProductDataSourceFactory` construye el data source adecuado para cada merchant:

- Si el sistema externo configurado es `patio_service`, crea `LegacyProductDataSource`.
- Para otro sistema —actualmente tratado como `merchant_panel`— crea `EcosystemProductDataSource`.

Cada data source recibe un Dio independiente con la URL y el token correspondientes al proveedor. Para Ecosystem también recibe los identificadores de compañía, canal y tienda.

### 6.4 Consideración de ciclo de vida

El service locator no implementa liberación o reconstrucción automática de las dependencias registradas durante `init()`. Si se modifican en ejecución valores que afectan clientes HTTP, es necesario revisar el flujo de recarga para garantizar que las instancias existentes adopten la nueva configuración. Esta limitación se detallará en la sección de configuración dinámica.

## 7. Modelo de dominio

El dominio contiene los datos y operaciones que representan el negocio sin incluir detalles de Flutter, almacenamiento o HTTP.

### 7.1 Entidad `Product`

Representa un producto que puede mostrarse y venderse.

| Campo | Tipo | Descripción |
| --- | --- | --- |
| `id` | `int` | Identificador del producto. |
| `merchantId` | `int` | Merchant propietario; permite combinar catálogos sin perder el origen. |
| `name` | `String` | Nombre visible. |
| `description` | `String` | Descripción comercial. |
| `price` | `double` | Precio efectivo utilizado para mostrar y cobrar. |
| `oldPrice` | `double?` | Precio anterior opcional, útil para promociones. |
| `urlImage` | `String` | Dirección de la imagen del producto. |

La entidad incluye `copyWith`, utilizado para producir una copia modificada sin cambiar la instancia original.

### 7.2 Entidad `Merchant`

Representa la información mínima de un comercio:

- `id`: identificador interno.
- `name`: nombre que puede mostrarse en la interfaz o incluirse en una orden.
- `urlLogo`: logotipo opcional.

### 7.3 Entidad `Order`

Representa una orden vinculada con el pago QR.

| Campo | Descripción |
| --- | --- |
| `orderId` | Identificador de la orden creada por el backend. |
| `qrBase64` | Imagen o contenido del QR devuelto para cobrar la orden. |
| `status` | Estado normalizado de la orden. |
| `dailyOrderNumber` | Número diario opcional entregado por el backend. |
| `storeName` | Nombre opcional de la tienda. |
| `provider` | Proveedor de pago opcional. |
| `externalId` | Identificador externo opcional del pago u orden. |

`OrderStatus` normaliza los estados relevantes en cuatro valores:

- `pending`: el pago todavía no fue confirmado.
- `confirmed`: el pago fue confirmado.
- `failed`: el pago falló.
- `unknown`: el backend devolvió un valor que la aplicación no reconoce.

### 7.4 Contrato de productos

`ProductRepository` define tres operaciones:

- Obtener un producto por merchant e identificador.
- Obtener el catálogo de un merchant.
- Obtener información del merchant.

La presentación trabaja contra este contrato. La decisión entre Legacy y Ecosystem pertenece a la implementación de datos.

### 7.5 Contrato de pagos

`QrPaymentRepository` define el ciclo de operaciones del pago:

- Crear la orden pendiente y generar su QR mediante `startQrPayment`.
- Consultar el estado mediante `getPaymentStatus`.
- Actualizar información del cliente mediante `updateOrder`.
- Marcar la orden como completada mediante `completeOrder`.

El inicio del pago recibe el merchant, datos básicos del cliente, ubicación de consumo, ítems del carrito, información del menú, monto y una referencia opcional de pago.

### 7.6 Casos de uso

Cada acción de dominio está encapsulada en una clase pequeña:

| Caso de uso | Responsabilidad |
| --- | --- |
| `GetProductUseCase` | Obtener un producto específico. |
| `GetProductsUseCase` | Obtener los productos de un merchant. |
| `GetMerchantInfoUseCase` | Obtener la información del comercio. |
| `StartQrPaymentUseCase` | Iniciar la orden y obtener el QR. |
| `GetPaymentStatusUseCase` | Consultar el estado actual del pago. |
| `UpdateOrderUseCase` | Actualizar datos de una orden existente. |
| `CompleteOrderUseCase` | Finalizar una orden confirmada. |

Los casos de uso son la frontera que consumen los Cubits. Esta estructura mantiene las decisiones de presentación separadas de la comunicación con servicios externos.

---

## 8. Carga y administración de productos

`HomeCubit` es el coordinador principal del catálogo que se presenta al usuario. Su constructor llama inmediatamente a `load()`, por lo que la carga inicial comienza al crear `HomePage` y su `BlocProvider`.

### 8.1 Carga inicial

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

### 8.2 Reintentos y fallos parciales

La carga completa permite un reintento adicional. Si el primer intento falla, espera dos segundos y vuelve a ejecutar la carga.

Dentro de cada intento, los merchants se procesan de forma independiente. `_loadSingleMerchant()` devuelve `null` si falla la carga de un comercio. Esto produce los siguientes comportamientos:

- Si falla un merchant pero al menos otro devuelve productos, la aplicación continúa con el catálogo parcial.
- Si ningún merchant devuelve productos, la carga se considera fallida.
- Si `MERCHANT_IDS` está vacío, la carga falla antes de llamar a las APIs.
- Después de agotar los intentos, `HomeCubit` emite `HomeStatus.error` con un mensaje para el usuario.

Aunque los merchants se cargan en paralelo, dentro de cada merchant la consulta de productos termina antes de solicitar su información general. Ambas operaciones reutilizan el mismo data source cacheado.

### 8.3 Catálogo combinado y origen del producto

Los productos de todos los merchants exitosos se agregan a una sola lista. Cada `Product` conserva `merchantId`, que permite:

- Determinar qué API debe validarlo antes del pago.
- Crear la orden con el merchant correcto.
- Resolver el nombre de la tienda mostrado o enviado en `menuData`.
- Agrupar productos por comercio en el endpoint interno `GET /products`.

`merchantIds` y `merchantNames` se mantienen como listas alineadas. `HomeState.getMerchantNameForProduct()` busca la posición del `merchantId` y devuelve el nombre ubicado en la misma posición. Si no encuentra una coincidencia, usa el nombre general combinado como fallback.

### 8.4 Las dos cachés relacionadas con productos

El proyecto mantiene dos cachés diferentes, con responsabilidades distintas:

| Caché | Ubicación | Contenido y propósito |
| --- | --- | --- |
| Caché de data sources | `ProductRepositoryImpl` | Un `ProductDataSource` por `merchantId`. Evita volver a consultar la configuración del merchant en cada carga o polling. |
| Caché de catálogo | `ProductCache` | Productos sin filtrar, nombres e IDs de merchants. Permite que `AppServer` consulte el catálogo sin depender directamente de `HomeCubit`. |

La caché de data sources mantiene además el cliente Dio y la decisión de proveedor tomada la primera vez que se consulta el merchant. La caché de catálogo se reemplaza con listas no modificables después de cada carga exitosa.

### 8.5 Actualización del catálogo

El catálogo puede actualizarse de tres formas:

- Una llamada explícita a `HomeCubit.load()`.
- Un comando `ReloadProduct`, normalmente emitido después de modificar configuración o filtros.
- Un polling bajo demanda o forzado.

Durante un polling, el Cubit compara los campos relevantes de los productos frescos con los actuales. Si existen cambios, vuelve a aplicar los filtros y procura conservar seleccionado el mismo producto mediante su identificador. Si el producto activo desapareció, reinicia el carrusel en cero. El algoritmo detallado del polling se describe en la sección 16.

## 9. Fuentes de productos

La aplicación puede obtener catálogos desde dos APIs con estructuras diferentes. El resto del sistema trabaja con la misma interfaz `ProductDataSource`, por lo que no necesita saber cuál proveedor fue seleccionado.

### 9.1 Resolución de la configuración del merchant

La primera operación para un merchant no cacheado es:

```http
GET {BASE_URL}/merchants/{merchantId}
Authorization: Bearer {BEARER_TOKEN}
```

`MerchantConfigFactory` interpreta la respuesta y consulta `configuration.externalSystem`:

- `patio_service` selecciona el proveedor Legacy.
- Cualquier otro valor selecciona Ecosystem; el código lo identifica actualmente como `merchant_panel`.

La configuración resultante contiene el identificador, nombre, logotipo, URL base, token y, cuando corresponde, los identificadores externos requeridos por Ecosystem.

### 9.2 Proveedor Legacy

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

### 9.3 Proveedor Ecosystem

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

### 9.4 Contrato común

Ambas implementaciones cumplen estas tres operaciones:

```text
getProducts()                 → List<Product>
getProduct(productId)        → Product
getMerchantInfo()            → Merchant
```

Esta normalización permite que `ProductRepositoryImpl`, los casos de uso y los Cubits funcionen igual con ambos proveedores.

## 10. Filtros y visibilidad de productos

`ProductFilterConfig` decide qué merchants y productos aparecen en el carrusel. La configuración contiene cuatro elementos:

| Propiedad | Significado |
| --- | --- |
| `enabledMerchants` | Merchants permitidos. Vacío significa que todos están habilitados. |
| `hiddenProducts` | IDs ocultos cuando el modo es `blacklist`. |
| `pinnedProducts` | IDs fijados o permitidos con prioridad especial. |
| `filterMode` | Estrategia activa: `all`, `blacklist` o `whitelist`. |

### 10.1 Orden de evaluación

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

### 10.2 Catálogo original frente a catálogo visible

`ProductCache.allProducts` conserva el resultado completo de las APIs. `HomeState.products` recibe únicamente los productos que pasan el filtro. Esta separación permite que los endpoints de administración informen productos ocultos y visibles sin tener que consultar nuevamente el backend.

`ProductCache.buildProductsResponse()` agrupa el catálogo por merchant e incluye por producto los campos `visible` y `pinned`. También calcula totales generales y por comercio.

### 10.3 Restablecimiento

`ProductFilterConfig.reset()`:

- Vacía merchants habilitados.
- Vacía productos ocultos.
- Vacía productos fijados.
- Restablece el modo a `all`.

Los endpoints que modifican y restablecen filtros, sus cuerpos JSON y su persistencia se documentarán junto con el catálogo de endpoints internos.

## 11. Manejo de estados

La aplicación usa Cubit, una variante de BLoC en la que cada método emite directamente el siguiente estado. La interfaz observa esos estados mediante `BlocProvider`, `BlocConsumer` y lecturas puntuales con `context.read`.

### 11.1 Estado de la pantalla principal

`HomeState` combina dos dimensiones independientes:

- `HomeStatus` representa la situación de los datos.
- `DisplayMode` representa qué experiencia debe verse en pantalla.

#### Estados de datos

| `HomeStatus` | Significado |
| --- | --- |
| `initial` | El Cubit todavía no terminó su primera operación. |
| `loading` | El catálogo se está cargando. |
| `loaded` | Existe un catálogo válido para presentar. |
| `error` | La carga falló y se conserva un mensaje de error. |

#### Modos visuales

| `DisplayMode` | Resultado visual |
| --- | --- |
| `idle` | Pantalla de espera con el texto “Esperando...”. |
| `attract` | GIF de atracción seleccionado en `attractGifAsset`. |
| `product` | Carga, error o carrusel según el valor de `HomeStatus`. |

Esta separación permite, por ejemplo, cargar datos mientras la pantalla se mantiene en modo de atracción o reposo.

### 11.2 Datos adicionales de `HomeState`

El estado guarda:

- Catálogo visible.
- Índice y producto actualmente seleccionados.
- Nombre general y nombres individuales de merchants.
- IDs de merchants cargados exitosamente.
- Cantidades del carrito (`cartQuantities`), mapeadas por clave `merchantId_productId`.
- Mensaje de sincronización del carrito (`cartSyncMessage`) y su revisión (`cartSyncRevision`).
- Mensaje de error.
- Fecha del último polling exitoso.
- Asset del GIF de atracción.

`HomeState` expone además:

- `quantityFor(Product)`: cantidad seleccionada de un producto.
- `cartProducts`: lista de productos con cantidad mayor a cero.
- `cartTotalItems`: suma de unidades en el carrito.
- `cartTotal`: monto total calculado con precios y cantidades actuales.

`HomeState` extiende `Equatable`, de modo que dos estados se comparan por el valor de sus propiedades. Sus colecciones se tratan como datos del estado y se reemplazan al actualizar el catálogo.

### 11.3 Transiciones principales de `HomeCubit`

```text
initial / idle
      │ constructor llama load()
      ▼
loading
  ├─ carga correcta → loaded / attract
  └─ carga fallida  → error

attract ── showProduct() ──→ product
product ── inactividad ─────→ attract
cualquier modo ─ showIdle() → idle
cualquier modo ─ showAttract() → attract
```

Al mover el carrusel, `updateCurrentIndex()` emite el índice nuevo y reinicia el temporizador de inactividad. El timeout se lee de `AppSettings().customerSessionTimeoutSeconds` (fallback 60 segundos). Cuando vence, el Cubit vuelve a `attract`.

`HomeCubit` expone operaciones de carrito:

- `incrementProduct(Product)`: aumenta la cantidad hasta `maxCartItemQuantity`.
- `decrementProduct(Product)`: reduce la cantidad; si llega a cero elimina la entrada.
- `removeProductFromCart(Product)`: elimina directamente un producto del carrito.
- `clearCart()`: vacía todas las cantidades.
- `registerCartInteraction()`: reinicia el timer de inactividad mientras el usuario opera el carrito.
- `pauseCustomerSessionTimeout()`: detiene el timer; se usa antes de navegar al pago.
- `resumeCustomerSessionTimeout()`: reanuda el timer cuando se regresa al catálogo.

`showProductResetCarousel()` realiza la misma entrada al catálogo, pero fuerza `currentIndex = 0`. Antes de mostrar productos, tanto este método como `showProduct()` comprueban si los datos necesitan actualizarse.

### 11.4 Estado del pago QR

`QrPaymentState` contiene:

| Propiedad | Propósito |
| --- | --- |
| `status` | Etapa principal del flujo. |
| `qrBase64` | Contenido o URL del QR generado. |
| `orderId` | Orden activa en el backend. |
| `errorMessage` | Mensaje recuperable para la UI. |
| `isPolling` | Indica si el timer de consulta está activo. |
| `amount` | Monto final validado y cobrado; puede diferir del monto inicial si los precios cambiaron. |

Los valores de `QrPaymentStatus` son:

| Estado | Significado |
| --- | --- |
| `initial` | No comenzó el pago. |
| `loading` | Se valida el producto, se crea la orden o se genera el QR. |
| `qrReady` | La orden y el QR están disponibles. Puede tener polling activo o detenido. |
| `success` | El backend confirmó el pago. |
| `failed` | Falló la generación, el producto dejó de existir o el pago fue rechazado/expiró. |
| `cancelled` | El flujo fue cancelado localmente. |

`copyWith()` usa un marcador interno para `qrBase64` y `orderId`. Esto permite distinguir entre “mantener el valor existente” y “asignar explícitamente `null`”, algo necesario cuando un pago fallido debe limpiar la orden y el QR.

### 11.5 Transiciones principales de `QrPaymentCubit`

```text
initial
   │ startQrPayment()
   ▼
loading
   ├─ producto inexistente / error → failed
   └─ orden + QR creados           → qrReady
                                         │
                              polling confirma estado
                                  ┌──────┴──────┐
                                  ▼             ▼
                               success        failed

initial/loading/qrReady/failed ── cancel() ──→ cancelled
cualquier estado ── reset() ─────────────────→ initial
```

Un pago exitoso tiene protección especial: `cancel()` detiene el timer pero no reemplaza `success` por `cancelled`. La página mantiene además un bloqueo local `_paymentSucceeded` para impedir que una reconstrucción tardía o el cierre de la ruta oculten el resultado exitoso.

### 11.6 Propiedad del ciclo de vida

`HomePage` posee el `HomeCubit` creado por su `BlocProvider`. Para cada navegación a pago crea un `QrPaymentCubit` nuevo y conserva temporalmente su referencia. Al cerrar la ruta, detiene el polling, cierra el Cubit y elimina la referencia.

Ambos Cubits cancelan sus timers en `close()`. Las páginas también cancelan timers visuales en `dispose()`, evitando que callbacks ya programados intenten modificar widgets desmontados.

## 12. Flujos de interfaz

### 12.1 Arranque y pantalla de atracción

El estado inicial combina `HomeStatus.initial` y `DisplayMode.idle`, pero `HomeCubit` inicia la carga inmediatamente. Cuando esta termina correctamente, emite `loaded + attract`; por tanto, la primera experiencia normal después del arranque es el GIF de atracción.

El asset predeterminado de `HomeState` es `assets/images/normal.gif`. El GIF puede cambiar mediante un comando y `setAttractGif()`. Entrar en modo de atracción cancela el temporizador de inactividad.

### 12.2 Entrada al catálogo

El catálogo puede mostrarse por una acción interna o por un comando recibido desde el servidor local:

- `ShowProduct` conserva el índice actual.
- `ShowProductResetCarousel` selecciona el primer producto.
- Los flujos de saludo pueden combinar el segundo comando con reproducción de audio.

Antes de mostrar el catálogo, el Cubit verifica la antigüedad de los productos. Si su estado anterior era `error`, intenta cargarlos nuevamente. La pantalla solo cambia efectivamente al catálogo cuando existe un estado `loaded`.

### 12.3 Presentación adaptable del catálogo

`HomePage` elige el layout según el ancho disponible:

- Con ancho mayor a 700 píxeles usa un layout horizontal: carrusel a la izquierda e información y acción de pago a la derecha.
- En pantallas más estrechas usa un layout vertical con carrusel, nombre, precio y botón.

El carrusel recibe la lista visible y el índice actual. Cuando el usuario cambia de producto, notifica a `HomeCubit`, que actualiza el índice y reinicia el timeout de cinco minutos.

### 12.4 Inicio del pago desde la interfaz

Al presionar **PAGAR PEDIDO CON QR**:

1. Se verifica que el carrito no esté vacío (`cartTotalItems > 0`).
2. Se pausa el timeout de sesión del `HomeCubit`.
3. Se fuerza un polling de productos para reconciliar el carrito con el catálogo más reciente.
4. Si el carrito fue ajustado o quedó vacío tras el polling, se reanuda el timeout y se muestra el aviso de sincronización.
5. Se cierra cualquier Cubit de pago anterior.
6. Se crea un `QrPaymentCubit` nuevo.
7. Se construye `cartItems` con todos los productos del carrito, sus cantidades y precios actuales.
8. Se construye `menuData` con el nombre del merchant y los datos visibles de cada producto.
9. Se navega a `QrPaymentPage`, entregándole el Cubit, el merchant del primer producto, el monto total y los datos anteriores.
10. Después del primer frame, la página llama a `startQrPayment()`.

La página muestra inicialmente un indicador con el mensaje “Verificando pedido y generando QR...”. Cuando el estado llega a `qrReady`, presenta el QR, el monto y el contador visual.

### 12.5 Contador visual del pago

`QrPaymentPage` inicia un contador local de diez segundos. El valor disminuye una vez por segundo hasta llegar a cero. En el código actual, este contador sirve como información o habilitación visual en `QrPaymentContent`; llegar a cero no cancela automáticamente la orden ni el polling.

La expiración real informada al usuario proviene de `QR_EXPIRATION_MINUTES`, que es independiente de este contador de diez segundos.

### 12.6 Pago exitoso y retorno

Cuando `QrPaymentCubit` emite `success`, la página:

- Fija `_paymentSucceeded` para dar prioridad permanente a la UI exitosa.
- Reproduce el audio de agradecimiento.
- Incrementa `PaymentCounter` con producto, merchant y monto.
- Muestra `PaymentResultWidget` con el mensaje de confirmación.
- Programa el retorno automático después de cinco segundos.

El callback de éxito detiene el polling, cierra la ruta y el Cubit de pago, y devuelve `HomeCubit` al modo de atracción.

### 12.7 Pago fallido

Un estado `failed` muestra el mensaje específico disponible o un mensaje general de rechazo/expiración. La pantalla ofrece:

- Reintentar el polling con la orden disponible en el estado.
- Volver a la pantalla anterior.

Cuando el backend reporta explícitamente un pago fallido, el Cubit limpia `orderId` y `qrBase64`. En ese caso, un simple reintento de polling no puede comenzar porque ya no hay orden activa; para generar una compra nueva debe reiniciarse el flujo desde el producto.

### 12.8 Cancelación y salida

La cancelación puede originarse en un comando externo o en la salida de la ruta. El comportamiento distingue dos acciones:

- `cancel()` detiene el polling y emite `cancelled`, salvo que el pago ya sea exitoso.
- `stopPollingOnly()` detiene el timer sin cambiar la etapa ni eliminar el QR.

Al disponer `QrPaymentPage` se usa la segunda opción para evitar un destello de “CANCELADO” después de mostrar “PAGO EXITOSO”. También se restablece el estado global publicado por `PaymentPollingStatus`.

Un comando externo `CancelPayment` cancela el Cubit activo, cierra la ruta si está abierta y muestra el catálogo con un timeout corto de cinco segundos antes de volver a atracción.

### 12.9 Reposo

`ShowIdle` cancela cualquier pago activo, cierra la ruta de pago y cambia la pantalla a `DisplayMode.idle`. La UI muestra “Esperando...”. Si el catálogo estaba en error, el Cubit intenta recargarlo en segundo plano sin abandonar conceptualmente el flujo de reposo solicitado.

### 12.10 Bus de comandos y navegación

`_HomeViewState` se suscribe al stream broadcast de `UiCommandBus` durante `initState()` y cancela la suscripción en `dispose()`. Los comandos de navegación producen estos efectos:

| Comando | Efecto principal |
| --- | --- |
| `ShowAttract` | Cancela pago, cierra la ruta y muestra atracción. |
| `ShowProduct` | Cancela pago, cierra la ruta y muestra el catálogo conservando el índice. |
| `ShowProductResetCarousel` | Cancela pago, cierra la ruta, muestra el catálogo y selecciona el primer producto. |
| `ShowIdle` | Cancela pago, cierra la ruta y muestra reposo. |
| `CancelPayment` | Cancela pago, cierra la ruta y muestra productos durante cinco segundos. |
| `ReloadProduct` | Ejecuta una carga completa del catálogo. |
| `ForceProductPoll` | Ejecuta un polling incondicional. |

Los comandos `StartPaymentPolling` y `StopPaymentPolling` no son procesados directamente por el `switch` de `HomePage`; su consumo depende del flujo de pago o componente que esté suscrito. Este comportamiento se detallará al documentar el polling y el servidor HTTP.

---

## 13. Generación del QR y flujo de pagos

El pago comienza validando cada producto del carrito contra su proveedor. `QrPaymentCubit` itera sobre `cartItems`, resuelve el `productId` de cada ítem (por ID explícito o por nombre dentro de `menuData`), y consulta el producto fresco mediante `_getProduct()`. Si algún producto ya no existe, el Cubit emite `failed` con un mensaje que indica qué ítem dejó de estar disponible. Si cambió de precio, actualiza el monto local de ese ítem y recalcula el total antes de crear la orden. Esta validación reduce el riesgo de cobrar información obsoleta del carrusel.

El monto final se redondea a dos decimales y se guarda en `QrPaymentState.amount`. Si el total validado es menor o igual a cero, el flujo se detiene con `failed`.

Después, `QrPaymentRepositoryImpl` realiza dos operaciones secuenciales:

1. `POST /orders/create-pending` crea la orden pendiente.
2. `POST /payments/qr/generate-payment` recibe `amount`, `merchantId` y `orderId`, y devuelve el QR.

La referencia de pago usa el valor sobrescrito por el llamador o genera `TOTEM-{timestamp}`. El carrito agrupa ítems por `id` cuando está disponible, o por nombre en minúsculas como fallback. Calcula subtotal y total, no aplica impuesto y usa `qr` como método de pago. La estructura exacta se encuentra en [API.md](docs/API.md).

`QrImageWidget` acepta una URL HTTP o una cadena Base64, con o sin prefijo de data URI. Si no puede decodificarla, presenta un fallback visual. La aplicación no construye criptográficamente el QR: solicita al backend la imagen o representación ya generada.

### 13.1 Dos modalidades vigentes

| Modalidad | Componente | Inicio del polling |
| --- | --- | --- |
| Página dedicada | `QrPaymentPage` | Automático después de generar el QR (`autoPoll: true`). |
| Panel embebido | `ProductQrPanelWrapper` | Manual mediante `StartPaymentPolling` (`autoPoll: false` inicialmente). |

El panel embebido mantiene una caché estática por clave `{merchantId}_{productId}`. Solo reutiliza la orden si merchant y monto coinciden y no transcurrió `QR_EXPIRATION_MINUTES`. Después de un pago exitoso invalida la entrada, muestra éxito durante cinco segundos y prepara un QR nuevo sin polling.

### 13.2 Confirmación y cierre

Al recibir un estado confirmado, `QrPaymentCubit` detiene el timer, solicita `POST /orders/complete/{orderId}` sin bloquear la UI y emite `success`. La pantalla reproduce agradecimiento, incrementa el contador en memoria y vuelve a atracción después de cinco segundos.

La finalización usa `catchError` vacío: un fallo del endpoint de completado no revierte el éxito visual ya confirmado por el endpoint de estado. Esta decisión prioriza la experiencia del usuario, pero requiere observabilidad externa si completar la orden es una operación crítica.

## 14. Polling de pagos y productos

### 14.1 Polling de pagos

`QrPaymentCubit` usa un `Timer.periodic` con intervalo predeterminado de tres segundos. Antes de iniciar uno nuevo cancela el anterior, por lo que un Cubit mantiene como máximo un timer activo.

Cada ciclo consulta `GET /payments/qr/status/{merchantId}/{orderId}`. Los estados externos se normalizan así:

- `SUCCESS` y `PAID` → confirmado.
- `FAILED`, `EXPIRED`, `CANCELLED`, `CLOSED` y `ERROR` → fallido.
- `PENDING` y `NOTFOUND` → pendiente.
- Cualquier otro valor → desconocido y el polling continúa.

Los errores HTTP durante un ciclo solo se registran; no detienen el timer ni cambian la UI. El polling termina al confirmar, fallar, cancelar, cerrar el Cubit o llamar `stopPollingOnly()`.

En el panel embebido, una solicitud manual recibida antes de que termine la generación queda marcada en `_pendingPollRequest` y se activa cuando existen orden y QR. `PaymentPollingStatus` publica las fases `idle`, `waiting`, `polling`, `success` y `failed` para consultas HTTP.

### 14.2 Polling de productos

No existe un timer periódico permanente para productos. El polling es bajo demanda al entrar al catálogo y solo ocurre cuando transcurrieron al menos `PRODUCT_POLLING_STALE_SECONDS`. Un valor menor o igual a cero lo deshabilita.

También puede forzarse sin considerar el umbral. La comparación considera longitud, orden, ID, merchant, nombre, precio, precio anterior, descripción e imagen. Sin cambios solo actualiza el timestamp interno; con cambios reemplaza estado y caché, conserva el producto activo por ID y mantiene el modo visual. Un error conserva silenciosamente el catálogo anterior.

Durante el polling, `HomeCubit` reconcilia el carrito con el catálogo fresco mediante `_reconcileCart()`:

- Si un producto del carrito desaparece del catálogo, se elimina del carrito y se genera un mensaje de aviso.
- Si un producto conservado cambió de precio, se mantiene la cantidad pero se genera un mensaje indicando que el precio fue actualizado.
- Las cantidades se conservan para los productos que siguen disponibles sin cambios de precio.

Los mensajes de sincronización se exponen en `HomeState.cartSyncMessage` y se muestran al usuario mediante un `SnackBar` cuando está en modo `product`. La revisión del mensaje (`cartSyncRevision`) permite distinguir avisos nuevos de los ya mostrados.

## 15. Servidor local, comandos y servicios compartidos

`AppServer` usa `dart:io` y enlaza el socket a `BASE_URL_VPN:PORT_VPN`. Acepta CORS desde cualquier origen, procesa preflight `OPTIONS` y responde JSON. No implementa autenticación propia, rate limiting ni TLS; debe considerarse una API de red confiable y limitarse mediante firewall o VPN.

El servidor no importa Cubits. Publica objetos en el stream broadcast `UiCommandBus`; los componentes visuales suscritos ejecutan el cambio correspondiente. Esta relación mantiene desacoplada la infraestructura HTTP de Flutter Presentation.

Los servicios singleton en memoria son:

- `ProductCache`: catálogo completo para consultas HTTP.
- `PaymentPollingStatus`: contexto y fase del pago visible.
- `PaymentCounter`: total, monto, últimas 50 ventas y resumen por producto.
- `AudioService`: reproductor único y cooldown.
- `AudioNotificationService`: stream para overlays visuales.

Su estado se pierde al reiniciar el proceso. El contrato completo del servidor y de las APIs externas está en [API.md](docs/API.md); el audio se documenta en [AUDIO.md](docs/AUDIO.md).

## 16. Configuración, operación y seguridad

Las variables se cargan desde `.env` al arrancar y se copian a `AppSettings`. Los detalles, fallbacks, formatos, configuración dinámica y manejo de secretos están en [CONFIGURATION.md](docs/CONFIGURATION.md).

La aplicación se puede ejecutar en Windows para desarrollo y compilar para Linux directamente o mediante Docker. Los scripts instalan en `/opt/mini_app_qr`, crean accesos `.desktop`, configuran autostart y mantienen el proceso en modo kiosco. El procedimiento y sus requisitos están en [DEPLOYMENT.md](docs/DEPLOYMENT.md).

## 17. Manejo de errores y recuperación

- La carga inicial reintenta una vez después de dos segundos.
- El fallo de un merchant no impide usar los demás.
- La UI de error de productos ofrece una recarga manual.
- Un polling de catálogo fallido mantiene los datos previos.
- Un producto eliminado antes de pagar bloquea la generación de la orden.
- Un precio actualizado reemplaza el monto local antes de cobrar.
- Un error al crear orden o QR muestra un mensaje genérico y recuperable.
- Un error aislado al consultar el pago no detiene futuros ciclos.
- Un estado externo fallido limpia orden y QR.
- Todos los timers relevantes se cancelan al cerrar sus Cubits o widgets.

Los errores se registran principalmente con `debugPrint` y algunos `print`. No existe actualmente un servicio centralizado de logs, métricas o reporte de excepciones.

## 18. Limitaciones y consideraciones técnicas

- `ARCHITECTURE.md` describe el código vigente; `remote-control/` está expresamente fuera de alcance.
- `AppSettings.load()` aplica el `.env` y fallbacks, pero no lee actualmente `ConfigStorage`.
- `POST /config` modifica memoria y no persiste en disco, pese a existir `ConfigStorage`.
- Cambiar URLs, tokens, host o puerto mediante HTTP exige reiniciar el proceso.
- Los clientes y data sources cacheados no se reconstruyen automáticamente.
- El servidor local expone el bearer token mediante `GET /config`; esto es sensible si la red no está aislada.
- CORS es permisivo y los endpoints internos no requieren autenticación.
- Contador, estado de polling, filtros, cachés de catálogo y QR viven en memoria.
- La comparación de productos depende también del orden devuelto por la API.
- `HomeState.currentProduct` asume un índice válido cuando la lista no está vacía; los layouts de catálogo esperan al menos un producto visible.
- El carrito se vacía al entrar en modo `attract` o `idle`; no persiste entre sesiones de cliente.
- La validación de productos antes del pago consulta la API por cada ítem del carrito, lo que aumenta la latencia de inicio proporcionalmente al número de productos.
- El panel embebido (`ProductQrPanelWrapper`) mantiene su caché por `{merchantId}_{productId}`; el flujo multi-producto de la página dedicada no utiliza esta caché.
- `assets/videos/` no está registrado en `pubspec.yaml`.
- El argumento `port` de `AppServer` no controla el bind actual; prevalece `AppSettings().portVpn`.
- La confirmación visual no espera que `completeOrder` termine correctamente.

## 19. Mapa de documentación

| Documento | Contenido |
| --- | --- |
| Este archivo | Diseño, capas, componentes, estados, productos, pagos, pollings y decisiones técnicas. |
| [API.md](docs/API.md) | Endpoints internos y externos, cuerpos, respuestas y efectos. |
| [CONFIGURATION.md](docs/CONFIGURATION.md) | Variables de entorno, fallbacks, configuración dinámica y secretos. |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | Desarrollo, compilación, empaquetado, instalación y kiosco Linux. |
| [AUDIO.md](docs/AUDIO.md) | Reproductor, cooldown, overlays, métodos y endpoints de audio. |

## 20. Diagrama de secuencia del pago

```text
Usuario        QrPaymentCubit       Product API       Orders API       Payments API
   │                  │                  │                 │                  │
   │ pagar            │                  │                 │                  │
   ├─────────────────►│ validar producto │                 │                  │
   │                  ├─────────────────►│                 │                  │
   │                  │◄─────────────────┤                 │                  │
   │                  │ crear pendiente                   │                  │
   │                  ├───────────────────────────────────►│                  │
   │                  │◄───────────────────────────────────┤ orderId          │
   │                  │ generar QR                                            │
   │                  ├──────────────────────────────────────────────────────►│
   │                  │◄──────────────────────────────────────────────────────┤
   │◄─────────────────┤ mostrar QR                                             │
   │                  │ GET status cada 3 s                                   │
   │                  ├──────────────────────────────────────────────────────►│
   │                  │◄──────────────────────────────────────────── confirmed│
   │                  │ completar orden                    │                  │
   │                  ├───────────────────────────────────►│                  │
   │◄─────────────────┤ éxito + audio + retorno                               │
```
