# Panel QR embebido y caché

Estados del flujo de QR embebido (`ProductQrPanelWrapper`). Este flujo está implementado pero utiliza polling manual por operador. Actualmente no es el flujo principal conectado desde `HomePage`, que usa `QrPaymentPage` con polling automático.

## Mermaid

```mermaid
stateDiagram-v2
    [*] --> Bootstrap
    Bootstrap --> QRReady: cache válida
    note right of QRReady
        Cache válida significa:
        - clave {merchantId}_{productId} existe
        - merchantId coincide
        - amount coincide
        - TTL no expirado
    end note
    Bootstrap --> Generating: cache ausente / expirada / monto distinto
    Generating --> QRReady: crear orden + QR sin polling
    Generating --> Failed: error o producto inválido
    QRReady --> Polling: StartPaymentPolling
    QRReady --> Generating: cache invalidada manualmente
    Polling --> Success: estado confirmado
    Polling --> Failed: rechazado / expirado
    Polling --> QRReady: StopPaymentPolling
    Success --> Generating: 5s / invalidar caché / regenerar QR sin polling
    Failed --> Generating: nueva generación
```

## PlantUML

```plantuml
@startuml
!theme plain
title Panel QR embebido y caché

[*] --> Bootstrap
Bootstrap --> QRReady : cache válida
note right of QRReady
    Cache válida significa:
    - clave {merchantId}_{productId} existe
    - merchantId coincide
    - amount coincide
    - TTL no expirado
end note
Bootstrap --> Generating : cache ausente / expirada / monto distinto
Generating --> QRReady : crear orden + QR sin polling
Generating --> Failed : error o producto inválido
QRReady --> Polling : StartPaymentPolling
QRReady --> Generating : cache invalidada manualmente
Polling --> Success : estado confirmado
Polling --> Failed : rechazado / expirado
Polling --> QRReady : StopPaymentPolling
Success --> Generating : 5s / invalidar caché / regenerar QR sin polling
Failed --> Generating : nueva generación

@enduml
```

## Notas importantes

- La caché es estática y compartida entre instancias del wrapper.
- La clave de caché es `{merchantId}_{productId}`.
- `StopPaymentPolling` detiene el timer pero **conserva** QR y orden, volviendo a `QRReady`.
- El éxito dura cinco segundos, luego se invalida la caché y se genera un QR nuevo sin polling.
- `PaymentPollingStatus` publica las fases `waiting`, `polling`, `success` y `failed` para consultas HTTP.

## Cuándo actualizar

- Cuando cambie la clave de caché o el TTL del QR embebido.
- Cuando se agregue un nuevo estado al panel.
- Cuando cambie el comportamiento post-éxito.
- Cuando el panel se conecte o desconecte del flujo principal.
