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

---

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

---

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

Para una versión interactiva con Mermaid que incluya servicios compartidos y consumidores externos, ver [diagrams/01-system-overview.md](diagrams/01-system-overview.md).

### 3.1 Capa `presentation`

Contiene todo lo relacionado con la experiencia visible y su estado:

- Las páginas principales, como `HomePage` y `QrPaymentPage`.
- Widgets del carrusel, tarjetas de producto, imágenes adaptativas (`AdaptiveProductImage`), QR, resultados, overlays de audio (`AudioOverlayWrapper`, `AudioOverlayWidget`), reproductor de GIF (`AttractGifPlayer`), selector de cantidad, carrito flotante y diálogo de facturación (`BillingFlowDialog`).
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

---

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
├── docs/
│   ├── ARCHITECTURE.md
│   ├── FLOWS.md
│   ├── STATE_MANAGEMENT.md
│   ├── CATALOG.md
│   ├── PAYMENT.md
│   ├── API.md
│   ├── CONFIGURATION.md
│   ├── AUDIO.md
│   ├── DEPLOYMENT.md
│   └── diagrams/
├── pubspec.yaml
├── .env_example
└── Dockerfile.linux
```

### 4.1 `lib/core`

- `config/`: carga y representa la configuración global (`AppSettings`), la selección de proveedores (`MerchantConfig`, `MerchantConfigFactory`), los filtros de productos (`ProductFilterConfig`) y la persistencia local (`ConfigStorage`).
- `constants/`: centraliza rutas o identificadores constantes, principalmente mensajes de audio (`AudioMessages`).
- `di/`: compone las dependencias de la aplicación mediante un service locator manual (`ServiceLocator`).
- `services/`: implementa el servidor local (`AppServer`), audio (`AudioService`), notificaciones de audio (`AudioNotificationService`), cachés (`ProductCache`), contador de ventas (`PaymentCounter`), estado de polling (`PaymentPollingStatus`) y comunicación por comandos (`UiCommandBus`).
- `ui/`: contiene elementos visuales compartidos, como la paleta de colores (`AppColors`).

### 4.2 `lib/data`

- `datasources/`: encapsula las llamadas HTTP de productos (`LegacyProductDataSource`, `EcosystemProductDataSource`) y pagos (`QrPaymentRemoteDataSource`).
- `factories/`: selecciona dinámicamente el data source de productos (`ProductDataSourceFactory`).
- `models/`: contiene DTOs para solicitudes y respuestas externas, incluyendo el subdirectorio `ecosystem/` con los modelos específicos del proveedor Ecosystem (`MenuResponseDto`, `MenuItemDto`, etc.).
- `repositories/`: implementa los contratos de dominio y coordina data sources y mapeos (`ProductRepositoryImpl`, `QrPaymentRepositoryImpl`).

### 4.3 `lib/domain`

- `entities/`: modelos independientes de infraestructura.
- `repositories/`: interfaces que describen las capacidades requeridas.
- `usecases/`: operaciones que los Cubits pueden ejecutar sin conocer detalles de red.

### 4.4 `lib/presentation`

- `bloc/`: Cubits y estados de la pantalla principal (`HomeCubit`, `HomeState`) y del pago QR (`QrPaymentCubit`, `QrPaymentState`).
- `pages/`: pantallas que organizan los flujos completos (`HomePage`, `QrPaymentPage`).
- `widgets/`: componentes visuales reutilizables y especializados:
  - **Carrusel y producto**: `ProductCarousel`, `ProductCard`, `CarouselSwipeHint`, `AdaptiveProductImage`.
  - **Carrito y cantidad**: `ProductQuantitySelector`, `FloatingCart`.
  - **Pago QR**: `QrPaymentContent`, `QrPaymentScreen`, `QrImageWidget`, `QrDisplayWidget`, `PaymentResultWidget`, `ProductQrPanel`, `ProductQrPanelWrapper`, `BillingFlowDialog`.
  - **Atracción y audio**: `AttractGifPlayer`, `AudioOverlayWrapper`, `AudioOverlayWidget`.
  - **Utilidades**: `AppImage` (carga de imágenes con caché opcional), `OrderSummary`.

### 4.5 Recursos y scripts

Los audios e imágenes están registrados en `pubspec.yaml` como recursos de Flutter. La aplicación utiliza imágenes animadas para sus distintos modos visuales (incluyendo GIFs de atracción como `normal`, `aura`, `kiss` y `six-seven`) y audios para saludos, instrucciones, notificaciones, confirmaciones y efectos adicionales (`dance_to_sell`, `reto_tokio`, entre otros).

La pantalla principal (`HomePage`) incluye branding visual: logo de Megacenter en la parte superior y firma de Nexus Patio Tech en la esquina inferior izquierda.

Aunque existe `assets/videos/`, en el `pubspec.yaml` vigente solo se registran `.env`, `assets/audio/` y `assets/images/`. Por lo tanto, cualquier video que se cargue como asset de Flutter debe registrarse antes de poder utilizarse en una compilación.

Los scripts de `scripts/linux/` cubren instalación, desinstalación, entrada y salida del modo kiosco e inicio automático. Los detalles operativos se documentan en [DEPLOYMENT.md](DEPLOYMENT.md).

---

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

Para el diagrama de secuencia completo, ver [diagrams/02-boot-sequence.md](diagrams/02-boot-sequence.md).

### 5.2 Configuración de escritorio

La ventana usa un tamaño inicial de 800 × 600, pero se abre en pantalla completa. La barra de título queda oculta. Esta configuración favorece el uso en un tótem o equipo dedicado, donde la aplicación debe ocupar toda la pantalla.

### 5.3 Inicio del servidor local

`main.dart` construye `AppServer(port: 8080)`, pero el servidor vigente enlaza el socket usando `AppSettings().portVpn`. En consecuencia, el argumento `8080` no determina actualmente el puerto real; prevalece `PORT_VPN`, cuyo fallback es `5050`.

El inicio del servidor no se espera con `await`. Se ejecuta concurrentemente mientras Flutter continúa construyendo la interfaz. Si el socket no puede abrirse, el error se registra, pero no impide que la aplicación gráfica arranque.

### 5.4 Aplicación raíz

`MyApp` configura un `MaterialApp` con Material 3, tema oscuro, colores personalizados y sin la etiqueta de depuración. `HomePage` es la pantalla raíz y desde ella se administran el catálogo, los modos visuales y el acceso al pago.

---

## 6. Inyección de dependencias

El proyecto usa un service locator manual definido en `lib/core/di/service_locator.dart`. Es un singleton global accesible mediante `sl`.

### 6.1 Dependencias de larga duración

Durante `sl.init()` se crean una sola vez:

- Un cliente Dio para órdenes y pagos, configurado con `BASE_URL` y `BEARER_TOKEN`.
- `ProductDataSourceFactory`, que incluye un segundo cliente Dio para consultar la configuración de merchants (`GET /merchants/{id}`).
- `QrPaymentRemoteDataSource`.
- Las implementaciones de `ProductRepository` y `QrPaymentRepository`.
- Todos los casos de uso de productos, merchants y pagos.

Los clientes Dio establecen tiempos máximos de conexión y respuesta de 20 segundos. También agregan los encabezados `Authorization: Bearer ...` y `Content-Type: application/json`.

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

Para el diagrama de este flujo, ver [diagrams/03-provider-selection.md](diagrams/03-provider-selection.md).

### 6.4 Consideración de ciclo de vida

El service locator no implementa liberación o reconstrucción automática de las dependencias registradas durante `init()`. Si se modifican en ejecución valores que afectan clientes HTTP, es necesario revisar el flujo de recarga para garantizar que las instancias existentes adopten la nueva configuración. Esta limitación se detalla en [CONFIGURATION.md](CONFIGURATION.md).

---

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

## 8. Servidor local y servicios compartidos

`AppServer` usa `dart:io` y enlaza el socket a `BASE_URL_VPN:PORT_VPN`. Acepta CORS desde cualquier origen, procesa preflight `OPTIONS` y responde JSON. No implementa autenticación propia, rate limiting ni TLS; debe considerarse una API de red confiable y limitarse mediante firewall o VPN.

El servidor expone endpoints agrupados por funcionalidad. El contrato completo de rutas, cuerpos y respuestas se encuentra en [API.md](API.md).

El servidor no importa Cubits. Publica objetos en el stream broadcast `UiCommandBus`; los componentes visuales suscritos ejecutan el cambio correspondiente. Esta relación mantiene desacoplada la infraestructura HTTP de Flutter Presentation.

Para el diagrama de este flujo, ver [diagrams/06-server-commands.md](diagrams/06-server-commands.md).

Los servicios singleton en memoria son:

- `ProductCache`: catálogo completo para consultas HTTP.
- `PaymentPollingStatus`: contexto y fase del pago visible (`idle`, `waiting`, `polling`, `success`, `failed`).
- `PaymentCounter`: total de órdenes, total de unidades, monto acumulado, últimas 50 órdenes y resumen acumulado por `merchantId` y `productId`.
- `AudioService`: reproductor único con cooldown anti-spam y soporte para llamadas remotas.
- `AudioNotificationService`: stream broadcast para overlays visuales de audio.

Su estado se pierde al reiniciar el proceso.

---

## 9. Limitaciones y consideraciones técnicas

- Este documento describe el código vigente; `remote-control/` está expresamente fuera de alcance.
- `AppSettings.load()` aplica el `.env` y fallbacks, pero no lee actualmente `ConfigStorage`.
- `POST /config` modifica memoria y no persiste en disco, pese a existir `ConfigStorage`.
- Cambiar URLs, tokens, host o puerto mediante HTTP exige reiniciar el proceso.
- Los clientes y data sources cacheados no se reconstruyen automáticamente.
- `GET /config` excluye el bearer token y otras credenciales de su respuesta.
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

---

## 10. Mapa de documentación

| Documento | Contenido |
| --- | --- |
| Este archivo | Diseño, capas, componentes, modelo de dominio y decisiones técnicas. |
| [FLOWS.md](FLOWS.md) | Inventario numerado de los 35 flujos del sistema. |
| [STATE_MANAGEMENT.md](STATE_MANAGEMENT.md) | Cubits, estados, transiciones, carrito y comandos de UI. |
| [CATALOG.md](CATALOG.md) | Carga de productos, proveedores Legacy/Ecosystem, filtros y polling. |
| [PAYMENT.md](PAYMENT.md) | Flujo QR, polling de pagos, panel embebido y confirmación. |
| [API.md](API.md) | Endpoints internos y externos, cuerpos, respuestas y efectos. |
| [CONFIGURATION.md](CONFIGURATION.md) | Variables de entorno, fallbacks, configuración dinámica y secretos. |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Desarrollo, compilación, empaquetado, instalación y kiosco Linux. |
| [AUDIO.md](AUDIO.md) | Reproductor, cooldown, overlays, métodos y endpoints de audio. |
| [diagrams/](diagrams/) | Diagramas Mermaid y PlantUML de arquitectura, secuencia, estados, flujos, audio, filtros, configuración y despliegue. |
