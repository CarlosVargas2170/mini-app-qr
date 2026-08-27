# Inventario de flujos del sistema

Este documento reúne los flujos observados en `lib/`, distinguiendo los iniciados por el cliente, por el operador remoto y por tareas internas.

---

## A.1 Flujos de arranque e infraestructura

1. **Arranque de la aplicación**: inicialización de Flutter y de la ventana, carga de `.env`, aplicación de valores fallback, composición del service locator, inicio concurrente de `AppServer` y construcción de `HomePage`.
2. **Inicio del servidor local**: bind en `BASE_URL_VPN:PORT_VPN`, configuración de CORS y despacho de peticiones HTTP a handlers internos.
3. **Composición de dependencias**: creación de clientes Dio, data sources, repositorios, casos de uso y factories; los Cubits se crean bajo demanda.
4. **Ciclo de vida y liberación**: cancelación de timers, suscripciones y Cubits al salir de páginas o cerrar la aplicación.

---

## A.2 Flujos de catálogo y productos

5. **Carga inicial del catálogo multi-merchant**: lectura de `MERCHANT_IDS`, carga paralela por merchant, obtención secuencial de productos e información del merchant, combinación de resultados y actualización de `ProductCache`.
6. **Reintento y degradación parcial**: un reintento global después de dos segundos; los merchants fallidos no bloquean los merchants exitosos, pero si fallan todos se muestra error.
7. **Resolución del proveedor**: consulta de configuración del merchant, selección de `LegacyProductDataSource` o `EcosystemProductDataSource` y cacheo del data source por `merchantId`.
8. **Carga Legacy**: categorías con productos → aplanado → entidades `Product`.
9. **Carga Ecosystem**: menú externo → descarte de ítems `inactive` → mapeo a entidades `Product`; la búsqueda de un producto o del merchant descarga el menú completo.
10. **Filtrado de visibilidad**: habilitación de merchants y evaluación de modos `all`, `blacklist` y `whitelist`, conservando separados catálogo completo y catálogo visible.
11. **Consulta administrativa de productos**: lectura HTTP de `ProductCache`, agrupación por merchant y exposición de `visible`/`pinned` y totales.
12. **Recarga completa**: llamada explícita, comando `ReloadProduct` o cambio de merchant/producto; vuelve a ejecutar la carga inicial.
13. **Polling bajo demanda de productos**: al mostrar el catálogo se comprueba staleness; un polling forzado ignora el umbral.
14. **Reconciliación del carrito**: comparación del catálogo fresco, eliminación de productos desaparecidos, conservación de cantidades y aviso por cambios de precio.

---

## A.3 Flujos de interacción y navegación

15. **Modo de atracción**: GIF actual, cancelación del timeout y vaciado del carrito; puede activarse desde UI o mediante comando HTTP.
16. **Entrada al catálogo**: muestra el carrusel, opcionalmente reinicia el índice, verifica staleness y activa el timeout de sesión.
17. **Modo reposo**: cancela el pago activo, cierra la ruta de pago, vacía el carrito y muestra `Esperando...`.
18. **Inactividad**: swipe o interacción del carrito reinicia el timer; al vencer vuelve automáticamente a atracción.
19. **Carrito**: incrementar, decrementar, eliminar, vaciar con confirmación, aplicar máximo por producto y calcular unidades/total.
20. **Comandos remotos de UI**: `AppServer` publica comandos en el bus broadcast; `HomePage` los traduce a navegación y cambios de estado sin importar Cubits desde infraestructura.
21. **Audio y overlay**: petición local o remota → cooldown/force → reproducción del asset → notificación visual opcional mediante `AudioNotificationService`.
22. **Cambio de GIF**: `POST /attract/set` actualiza el nombre global, publica `ShowAttract` y la UI cambia inmediatamente de asset.

---

## A.4 Flujos de pago QR

23. **Preparación del pago desde carrito**: valida carrito no vacío, pausa el timeout, fuerza polling de productos y aborta si el carrito cambió o quedó vacío.
24. **Validación pre-pago**: resuelve el ID de cada ítem, consulta el producto fresco, actualiza nombre/precio/menuData y recalcula el monto.
25. **Creación del pago**: `POST /orders/create-pending` → `orderId` → `POST /payments/qr/generate-payment` → QR.
26. **Polling automático de página dedicada**: cada tres segundos consulta el estado del pago; estados externos se normalizan a pendiente, confirmado o fallido.
27. **Confirmación y cierre**: detiene polling, dispara completion sin bloquear la UI, reproduce agradecimiento, registra en el contador la orden con todas las líneas y cantidades del carrito, y retorna a atracción después de cinco segundos.
28. **Pago fallido**: detiene polling, limpia orden y QR cuando corresponde y permite volver o reintentar si aún existe una orden.
29. **Cancelación y salida**: `cancel()` emite `cancelled`; al hacer pop se usa `stopPollingOnly()` para no sobrescribir un éxito ya mostrado.
30. **Panel QR embebido**: generación sin polling, reutilización de caché por `{merchantId}_{productId}`, activación manual por operador, éxito temporal, invalidación y regeneración de QR.
31. **Publicación del estado de pago**: `QrPaymentPage` o el panel sincronizan `PaymentPollingStatus`, consultable desde `GET /payment/polling-status`.

---

## A.5 Flujos de configuración, operación y despliegue

32. **Configuración en runtime**: `GET /config` expone configuración y `POST /config` modifica memoria; merchant/producto provoca reload y URLs, tokens, host o puerto requieren reinicio.
33. **Administración de filtros**: `POST /products/filter` cambia filtros en memoria y opcionalmente emite reload; `reset` restaura el modo `all`.
34. **Control operativo del contador**: después de cada pago exitoso registra una orden y sus unidades por producto, se consulta junto al estado remoto y se reinicia mediante `/payment/reset-counter`.
35. **Ejecución y empaquetado**: desarrollo en Windows, build Linux, imagen o scripts de instalación/kiosco y autostart.

---

## A.6 Flujos que conviene vigilar especialmente

- **Configuración sensible**: `GET /config` omite `bearerToken` y otras credenciales; el servidor local sigue sin autenticación, TLS ni rate limiting.
- **Configuración dinámica incompleta**: los clientes Dio y data sources cacheados no se reconstruyen tras cambiar URLs o tokens.
- **Consistencia del pago**: la UI muestra éxito aunque `completeOrder` falle; se requiere logging/observabilidad externa para detectar ese caso.
- **Carrera de comandos**: las respuestas HTTP confirman la emisión del comando, no que la UI haya terminado de procesarlo.
- **Estado volátil**: filtros, carrito, contador, cachés, QR y estado de polling se pierden al reiniciar el proceso.
