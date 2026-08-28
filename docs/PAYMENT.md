# Generación del QR y flujo de pagos

Este documento describe el ciclo de vida completo del pago QR, desde la validación del carrito hasta la confirmación o fallo, incluyendo el panel embebido y el polling de estado.

---

## 1. Validación y generación

### 1.1 Datos de facturación

Antes de iniciar la validación del carrito, el sistema presenta un diálogo de facturación (`BillingFlowDialog`). El usuario puede:

- Elegir **"Sin factura"** para continuar sin datos adicionales.
- Elegir **"Con factura"** para ingresar NIT y razón social.

Si el usuario cierra el diálogo sin seleccionar una opción, el flujo de pago se aborta y se reanuda el timeout de sesión del catálogo. Los datos capturados se propagan hasta `QrPaymentCubit.startQrPayment` y se incluyen en el payload de `POST /orders/create-pending` como `nit` y `businessName`.

### 1.2 Validación de productos y generación del QR

El pago comienza validando cada producto del carrito contra su proveedor. `QrPaymentCubit` itera sobre `cartItems`, resuelve el `productId` de cada ítem (por ID explícito o por nombre dentro de `menuData`), y consulta el producto fresco mediante `_getProduct()`. Si algún producto ya no existe, el Cubit emite `failed` con un mensaje que indica qué ítem dejó de estar disponible. Si cambió de precio, actualiza el monto local de ese ítem y recalcula el total antes de crear la orden. Esta validación reduce el riesgo de cobrar información obsoleta del carrusel.

El monto final se redondea a dos decimales y se guarda en `QrPaymentState.amount`. Si el total validado es menor o igual a cero, el flujo se detiene con `failed`.

Después, `QrPaymentRepositoryImpl` realiza dos operaciones secuenciales:

1. `POST /orders/create-pending` crea la orden pendiente, incluyendo `nit` y `businessName` cuando fueron proporcionados.
2. `POST /payments/qr/generate-payment` recibe `amount`, `merchantId` y `orderId`, y devuelve el QR.

La referencia de pago usa el valor sobrescrito por el llamador o genera `TOTEM-{timestamp}`. El carrito agrupa ítems por `id` cuando está disponible, o por nombre en minúsculas como fallback. Calcula subtotal y total, no aplica impuesto y usa `qr` como método de pago. La estructura exacta se encuentra en [API.md](API.md).

`QrImageWidget` acepta una URL HTTP o una cadena Base64, con o sin prefijo de data URI. Si no puede decodificarla, presenta un fallback visual. La aplicación no construye criptográficamente el QR: solicita al backend la imagen o representación ya generada.

---

## 2. Dos modalidades vigentes

| Modalidad | Componente | Inicio del polling |
| --- | --- | --- |
| Página dedicada | `QrPaymentPage` | Automático después de generar el QR (`autoPoll: true`). |
| Panel embebido | `ProductQrPanelWrapper` | Manual mediante `StartPaymentPolling` (`autoPoll: false` inicialmente). |

El panel embebido mantiene una caché estática por clave `{merchantId}_{productId}`. Solo reutiliza la orden si merchant y monto coinciden y no transcurrió `QR_EXPIRATION_MINUTES`. Después de un pago exitoso invalida la entrada, muestra éxito durante cinco segundos y prepara un QR nuevo sin polling.

> **Estado de conexión:** `ProductQrPanelWrapper` está implementado pero no conectado al flujo principal de `HomePage`. El flujo activo usa `QrPaymentPage` con polling automático.

`QrPaymentCubit` expone métodos para soportar ambas modalidades:

- `restoreQr({orderId, qrBase64})`: restablece un QR existente sin iniciar polling (usado al recuperar de caché).
- `beginPolling(merchantId, {orderId, qrBase64})`: inicia o reanuda el polling manual sobre un QR disponible.
- `stopPollingOnly()`: detiene el timer sin cancelar la orden ni limpiar el QR (usado al salir del panel o de la página).

---

## 3. Confirmación y cierre

Al recibir un estado confirmado, `QrPaymentCubit` detiene el timer, solicita `POST /orders/complete/{orderId}` sin bloquear la UI y emite `success`. La pantalla reproduce agradecimiento, registra en el contador en memoria una orden con todas las líneas y cantidades del carrito, y vuelve a atracción después de cinco segundos.

La finalización usa `catchError` vacío: un fallo del endpoint de completado no revierte el éxito visual ya confirmado por el endpoint de estado. Esta decisión prioriza la experiencia del usuario, pero requiere observabilidad externa si completar la orden es una operación crítica.

## 4. Casos de error durante el flujo de pago

El flujo puede fallar en varios puntos:

1. **Carrito vacío o cambiado tras polling:** se aborta antes de crear el `QrPaymentCubit`.
2. **Producto inválido o cantidad menor o igual a cero:** se emite `failed` con mensaje descriptivo.
3. **Producto no encontrado en la API:** se emite `failed` indicando qué ítem dejó de estar disponible.
4. **Cambio de precio:** se actualiza el precio local, se recalcula el total y se continúa.
5. **Total menor o igual a cero:** se emite `failed` con mensaje de total inválido.
6. **Error creando orden pendiente o generando QR:** se emite `failed` con mensaje genérico recuperable.
7. **Estado desconocido del backend:** el polling continúa.
8. **Error HTTP durante un ciclo de polling:** se loguea y continúa el timer.
9. **Pago fallido por backend:** se limpian `orderId` y `qrBase64`; un simple reintento no puede comenzar.
10. **`completeOrder` falla:** la UI muestra éxito igualmente.

## 5. Consideración multi-merchant

Actualmente `QrPaymentPage` recibe el `merchantId` del **primer producto del carrito**. Todos los ítems se validan contra ese mismo merchant. Si el carrito contiene productos de distintos merchants, esto puede generar inconsistencias o fallos de validación.

Esta limitación debe revisarse si el negocio requiere pagos multi-merchant reales.

---

## 6. Polling de pagos

`QrPaymentCubit` usa un `Timer.periodic` con intervalo predeterminado de tres segundos. Antes de iniciar uno nuevo cancela el anterior, por lo que un Cubit mantiene como máximo un timer activo.

Cada ciclo consulta `GET /payments/qr/status/{merchantId}/{orderId}`. Los estados externos se normalizan así:

- `SUCCESS` y `PAID` → confirmado.
- `FAILED`, `EXPIRED`, `CANCELLED`, `CLOSED` y `ERROR` → fallido.
- `PENDING` y `NOTFOUND` → pendiente.
- Cualquier otro valor → desconocido y el polling continúa.

Los errores HTTP durante un ciclo solo se registran; no detienen el timer ni cambian la UI. El polling termina al confirmar, fallar, cancelar, cerrar el Cubit o llamar `stopPollingOnly()`.

En el panel embebido, una solicitud manual recibida antes de que termine la generación queda marcada en `_pendingPollRequest` y se activa cuando existen orden y QR. `PaymentPollingStatus` publica las fases `idle`, `waiting`, `polling`, `success` y `failed` para consultas HTTP.

---

## 7. Cancelación y salida

La cancelación puede originarse en un comando externo o en la salida de la ruta. El comportamiento distingue dos acciones:

- `cancel()` detiene el polling y emite `cancelled`, salvo que el pago ya sea exitoso.
- `stopPollingOnly()` detiene el timer sin cambiar la etapa ni eliminar el QR.

Al disponer `QrPaymentPage` se usa la segunda opción para evitar un destello de "CANCELADO" después de mostrar "PAGO EXITOSO". También se restablece el estado global publicado por `PaymentPollingStatus`.

Un comando externo `CancelPayment` cancela el Cubit activo, cierra la ruta si está abierta y muestra el catálogo con un timeout corto de cinco segundos antes de volver a atracción.

---

## 8. Diagrama de secuencia del pago

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

---

## Referencias

- [Diagrama de secuencia de pago QR](diagrams/05-payment-sequence.md)
- [Diagrama de comparación de flujos de pago](diagrams/09-payment-flows-comparison.md)
- [Diagrama de panel QR embebido](diagrams/07-embedded-qr.md)
- [Diagrama de estado remoto del pago](diagrams/12-payment-remote-status.md)
- [Diagrama de manejo de errores](diagrams/15-error-handling.md)
- [Estados de Cubits y UI](STATE_MANAGEMENT.md)
- [Flujo del carrito](diagrams/10-cart-flow.md)
- [API de órdenes y pagos](API.md)
