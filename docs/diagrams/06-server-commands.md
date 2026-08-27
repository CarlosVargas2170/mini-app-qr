# Servidor local y bus de comandos

Muestra cómo los consumidores externos interactúan con `AppServer`, qué endpoints publican comandos en `UiCommandBus`, cuáles actúan directamente sobre servicios singleton, y cuál es el puerto real de escucha.

## Mermaid

```mermaid
flowchart LR
    subgraph Remote
        R[Robot / operador / servicio VPN]
    end

    subgraph AppServer
        S[AppServer]
        CORS[CORS permisivo]
        404[Respuesta 404 JSON]
    end

    subgraph ComandosUI
        Bus[UiCommandBus broadcast]
        Home[HomePage + HomeCubit]
        Panel[ProductQrPanelWrapper]
    end

    subgraph ServiciosDirectos
        Audio[AudioService]
        Status[PaymentPollingStatus]
        Counter[PaymentCounter]
        Cache[ProductCache]
        Settings[AppSettings en memoria]
        Attract[UiCommandBus.currentGifName]
    end

    R -->|POST /audio/*| S
    S --> Audio

    R -->|POST /greet /product<br/>/proximity/* /cancel-payment| S
    S --> Bus
    Bus --> Home

    R -->|POST /payment/start-polling<br/>POST /payment/stop-polling| S
    S --> Bus
    Bus --> Panel

    R -->|GET /payment/polling-status| S
    S --> Status

    R -->|POST /payment/reset-counter| S
    S --> Counter

    R -->|GET /products| S
    S --> Cache

    R -->|POST /products/reload/filter/polling/force| S
    S --> Bus
    Bus --> Home

    R -->|GET /config| S
    S --> Settings

    R -->|POST /config| S
    S --> Settings
    Settings -->|needsReload| Bus
    Bus --> Home

    R -->|POST /attract/set| S
    S --> Bus
    Bus --> Home
    S --> Attract

    R -->|GET /attract/current| S
    S --> Attract

    Note1[El puerto real de escucha es AppSettings.portVpn<br/>normalmente 5050, no el 8080 del constructor]
    S -.-> Note1
```

## PlantUML

```plantuml
@startuml
!theme plain
title Servidor local y bus de comandos

actor "Robot / operador / servicio VPN" as R

package "AppServer" {
    [AppServer] as S
    note right of S
        Puerto real: AppSettings.portVpn
        (normalmente 5050, no 8080 del constructor)
    end note
}

package "Comandos UI" {
    [UiCommandBus broadcast] as Bus
    [HomePage + HomeCubit] as Home
    [ProductQrPanelWrapper] as Panel
}

package "Servicios directos" {
    [AudioService] as Audio
    [PaymentPollingStatus] as Status
    [PaymentCounter] as Counter
    [ProductCache] as Cache
    [AppSettings en memoria] as Settings
    [UiCommandBus.currentGifName] as Attract
}

R --> S : POST /audio/*
S --> Audio

R --> S : POST /greet /product\n/proximity/* /cancel-payment
S --> Bus
Bus --> Home

R --> S : POST /payment/start-polling\nPOST /payment/stop-polling
S --> Bus
Bus --> Panel

R --> S : GET /payment/polling-status
S --> Status

R --> S : POST /payment/reset-counter
S --> Counter

R --> S : GET /products
S --> Cache

R --> S : POST /products/reload/filter/polling/force
S --> Bus
Bus --> Home

R --> S : GET /config
S --> Settings

R --> S : POST /config
S --> Settings
Settings --> Bus : needsReload
Bus --> Home

R --> S : POST /attract/set
S --> Bus
Bus --> Home
S --> Attract

R --> S : GET /attract/current
S --> Attract

@enduml
```

## Cuándo actualizar

- Cuando se agregue o elimine un endpoint del servidor local.
- Cuando cambie la forma en que los comandos se publican o consumen.
- Cuando se incorpore un nuevo servicio singleton expuesto por HTTP.
- Cuando se unifique el puerto del constructor con el puerto real de bind.
