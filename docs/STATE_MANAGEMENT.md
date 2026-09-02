# Manejo de estados e interfaz

Este documento describe los estados de la aplicación, las transiciones de los Cubits y los flujos de interacción visibles para el usuario.

---

## 1. Estado de la pantalla principal

`HomeState` combina dos dimensiones independientes:

- `HomeStatus` representa la situación de los datos.
- `DisplayMode` representa qué experiencia debe verse en pantalla.

### 1.1 Estados de datos

| `HomeStatus` | Significado |
| --- | --- |
| `initial` | El Cubit todavía no terminó su primera operación. |
| `loading` | El catálogo se está cargando. |
| `loaded` | Existe un catálogo válido para presentar. |
| `error` | La carga falló y se conserva un mensaje de error. |

### 1.2 Modos visuales

| `DisplayMode` | Resultado visual |
| --- | --- |
| `idle` | Pantalla de espera con el texto "Esperando...". |
| `attract` | GIF de atracción seleccionado en `attractGifAsset`, con transiciones suaves de fade entre cambios. |
| `product` | Carga, error o carrusel según el valor de `HomeStatus`. |

> **Importante:** `DisplayMode` solo describe lo que ocurre dentro de `HomePage`. El pago QR no es un modo visual de Home; se realiza en una ruta separada (`QrPaymentPage`) con sus propios estados (`QrPaymentStatus`).

Esta separación permite, por ejemplo, cargar datos mientras la pantalla se mantiene en modo de atracción o reposo.

### 1.3 Datos adicionales de `HomeState`

El estado guarda:

- Catálogo visible.
- Índice y producto actualmente seleccionados.
- Nombre general y nombres individuales de merchants.
- IDs de merchants cargados exitosamente, y el mapa `merchantsById` (`Map<int, Merchant>`) con la información de cada comercio.
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
- `merchantUsesBilling(merchantId)`: indica si el merchant correspondiente tiene facturación habilitada (`billingType != 'none'`).

`HomeState` extiende `Equatable`, de modo que dos estados se comparan por el valor de sus propiedades. Sus colecciones se tratan como datos del estado y se reemplazan al actualizar el catálogo.

---

## 2. Transiciones principales de `HomeCubit`

```text
initial / idle
      │ constructor llama load()
      ▼
loading
  ├─ carga correcta (posiblemente con merchants parciales) → loaded / attract
  ├─ carga fallida tras reintentos → error
  └─ un merchant falla pero otros no → loaded / attract (parcial)

attract ── showProduct() ──→ product
product ── inactividad ─────→ attract
cualquier modo ─ showIdle() → idle
cualquier modo ─ showAttract() → attract

product + carrito válido ── Navigator.push ──→ QrPaymentPage
```

Al mover el carrusel, `updateCurrentIndex()` emite el índice nuevo y reinicia el temporizador de inactividad. El timeout se lee de `AppSettings().customerSessionTimeoutSeconds` (fallback 60 segundos). Cuando vence, el Cubit vuelve a `attract`.

`HomeCubit` expone operaciones de carrito y navegación:

- `incrementProduct(Product)`: aumenta la cantidad hasta `maxCartItemQuantity`.
- `decrementProduct(Product)`: reduce la cantidad; si llega a cero elimina la entrada.
- `removeProductFromCart(Product)`: elimina directamente un producto del carrito.
- `clearCart()`: vacía todas las cantidades.
- `registerCartInteraction()`: reinicia el timer de inactividad mientras el usuario opera el carrito.
- `pauseCustomerSessionTimeout()`: detiene el timer; se usa antes de navegar al pago.
- `resumeCustomerSessionTimeout()`: reanuda el timer cuando se regresa al catálogo.
- `showProductWithTimeout(Duration)`: muestra el catálogo con un timeout de inactividad personalizado (usado por `CancelPayment` para volver a `attract` tras cinco segundos).

`showProductResetCarousel()` realiza la misma entrada al catálogo, pero fuerza `currentIndex = 0`. Antes de mostrar productos, tanto este método como `showProduct()` comprueban si los datos necesitan actualizarse.

---

## 3. Estado del pago QR

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

`copyWith()` usa un marcador interno para `qrBase64` y `orderId`. Esto permite distinguir entre "mantener el valor existente" y "asignar explícitamente `null`", algo necesario cuando un pago fallido debe limpiar la orden y el QR.

### 3.1 Transiciones principales de `QrPaymentCubit`

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

---

## 4. Flujos de interfaz

### 4.1 Arranque y pantalla de atracción

El estado inicial combina `HomeStatus.initial` y `DisplayMode.idle`, pero `HomeCubit` inicia la carga inmediatamente. Cuando esta termina correctamente, emite `loaded + attract`; por tanto, la primera experiencia normal después del arranque es el GIF de atracción.

El asset predeterminado de `HomeState` es `assets/images/normal.gif`. El GIF puede cambiar mediante un comando y `setAttractGif()`. Entrar en modo de atracción cancela el temporizador de inactividad.

### 4.2 Entrada al catálogo

El catálogo puede mostrarse por una acción interna o por un comando recibido desde el servidor local:

- `ShowProduct` conserva el índice actual.
- `ShowProductResetCarousel` selecciona el primer producto.
- Los flujos de saludo pueden combinar el segundo comando con reproducción de audio.

Antes de mostrar el catálogo, el Cubit verifica la antigüedad de los productos. Si su estado anterior era `error`, intenta cargarlos nuevamente. La pantalla solo cambia efectivamente al catálogo cuando existe un estado `loaded`.

### 4.3 Presentación adaptable del catálogo

`HomePage` elige el layout según el ancho disponible:

- Con ancho mayor a 700 píxeles usa un layout horizontal: carrusel a la izquierda e información y acción de pago a la derecha.
- En pantallas más estrechas usa un layout vertical con carrusel, nombre, precio y botón.

El carrusel recibe la lista visible y el índice actual. Cuando el usuario cambia de producto, notifica a `HomeCubit`, que actualiza el índice y reinicia el timeout de inactividad configurado (`customerSessionTimeoutSeconds`, fallback 60 segundos).

### 4.4 Inicio del pago desde la interfaz

Al presionar **PAGAR PEDIDO CON QR**:

1. Se verifica que el carrito no esté vacío (`cartTotalItems > 0`).
2. Se pausa el timeout de sesión del `HomeCubit`.
3. Si el merchant del primer producto tiene facturación habilitada (`merchantUsesBilling`), se presenta `BillingFlowDialog` para que el usuario elija si requiere factura. Si el merchant no factura, se continúa directamente sin datos de facturación. Si el usuario cierra el diálogo sin continuar, se aborta el flujo y se reanuda el timeout.
4. Se fuerza un polling de productos para reconciliar el carrito con el catálogo más reciente.
5. Si el carrito fue ajustado o quedó vacío tras el polling, se reanuda el timeout y se muestra el aviso de sincronización.
6. Se cierra cualquier Cubit de pago anterior.
7. Se crea un `QrPaymentCubit` nuevo.
8. Se construye `cartItems` con todos los productos del carrito, sus cantidades y precios actuales.
9. Se construye `menuData` con el nombre del merchant y los datos visibles de cada producto.
10. Se navega a `QrPaymentPage`, entregándole el Cubit, el **merchant del primer producto**, el monto total, los datos de facturación (`nit`, `businessName`) y los datos anteriores.
11. Después del primer frame, la página llama a `startQrPayment()`.

> **Nota sobre multi-merchant:** actualmente el `merchantId` usado para validar productos y crear la orden proviene del primer producto del carrito. Esto puede ser una limitación si el carrito contiene productos de distintos merchants.

La página muestra inicialmente un indicador con el mensaje "Verificando pedido y generando QR...". Cuando el estado llega a `qrReady`, presenta el QR, el monto y el contador visual.

### 4.5 Contador visual del pago

`QrPaymentPage` inicia un contador local de diez segundos. El valor disminuye una vez por segundo hasta llegar a cero. En el código actual, este contador sirve como información o habilitación visual en `QrPaymentContent`; llegar a cero no cancela automáticamente la orden ni el polling.

La expiración real informada al usuario proviene de `QR_EXPIRATION_MINUTES`, que es independiente de este contador de diez segundos.

### 4.6 Pago exitoso y retorno

Cuando `QrPaymentCubit` emite `success`, la página:

- Fija `_paymentSucceeded` para dar prioridad permanente a la UI exitosa.
- Reproduce el audio de agradecimiento.
- Registra en `PaymentCounter` el merchant, el monto y el carrito completo con las cantidades vendidas por producto.
- Muestra `PaymentResultWidget` con el mensaje de confirmación.
- Programa el retorno automático después de cinco segundos.

El callback de éxito detiene el polling, cierra la ruta y el Cubit de pago, y devuelve `HomeCubit` al modo de atracción.

### 4.7 Pago fallido

Un estado `failed` muestra el mensaje específico disponible o un mensaje general de rechazo/expiración. La pantalla ofrece:

- Reintentar el polling con la orden disponible en el estado.
- Volver a la pantalla anterior.

Cuando el backend reporta explícitamente un pago fallido, el Cubit limpia `orderId` y `qrBase64`. En ese caso, un simple reintento de polling no puede comenzar porque ya no hay orden activa; para generar una compra nueva debe reiniciarse el flujo desde el producto.

### 4.8 Cancelación y salida

La cancelación puede originarse en un comando externo o en la salida de la ruta. El comportamiento distingue dos acciones:

- `cancel()` detiene el polling y emite `cancelled`, salvo que el pago ya sea exitoso.
- `stopPollingOnly()` detiene el timer sin cambiar la etapa ni eliminar el QR.

Al disponer `QrPaymentPage` se usa la segunda opción para evitar un destello de "CANCELADO" después de mostrar "PAGO EXITOSO". También se restablece el estado global publicado por `PaymentPollingStatus`.

Un comando externo `CancelPayment` cancela el Cubit activo, cierra la ruta si está abierta y muestra el catálogo con un timeout corto de cinco segundos antes de volver a atracción.

### 4.9 Reposo

`ShowIdle` cancela cualquier pago activo, cierra la ruta de pago y cambia la pantalla a `DisplayMode.idle`. La UI muestra "Esperando...". Si el catálogo estaba en error, el Cubit intenta recargarlo en segundo plano sin abandonar conceptualmente el flujo de reposo solicitado.

---

## 5. Bus de comandos y navegación

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

Los comandos `StartPaymentPolling` y `StopPaymentPolling` no son procesados directamente por el `switch` de `HomePage`; son consumidos por `ProductQrPanelWrapper`, que gestiona el polling manual del QR embebido. Actualmente `ProductQrPanelWrapper` no está conectado al flujo principal de `HomePage`; el flujo activo desde Home usa `QrPaymentPage` con polling automático.

---

## 6. Propiedad del ciclo de vida

`HomePage` posee el `HomeCubit` creado por su `BlocProvider`. Para cada navegación a pago crea un `QrPaymentCubit` nuevo y conserva temporalmente su referencia. Al cerrar la ruta, detiene el polling, cierra el Cubit y elimina la referencia.

Ambos Cubits cancelan sus timers en `close()`. Las páginas también cancelan timers visuales en `dispose()`, evitando que callbacks ya programados intenten modificar widgets desmontados.

---

## Referencias

- [Diagrama de estados de la pantalla principal](diagrams/04-home-states.md)
- [Diagrama de comparación de flujos de pago](diagrams/09-payment-flows-comparison.md)
- [Diagrama de flujo del carrito](diagrams/10-cart-flow.md)
- [Diagrama de servidor local y bus de comandos](diagrams/06-server-commands.md)
- [Flujo de pago QR](PAYMENT.md)
- [Inventario completo de flujos](FLOWS.md)
