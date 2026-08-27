# Estados de interacción de la pantalla principal

Muestra los dos modelos de estado involucrados en `HomePage`: los modos visuales (`DisplayMode`) y los estados de datos (`HomeStatus`). El pago se realiza en una ruta separada (`QrPaymentPage`), no es un modo visual de Home.

## Mermaid

```mermaid
stateDiagram-v2
    state "HomePage" as Home {
        [*] --> Idle
        Idle --> Attract: load OK / ShowAttract
        Attract --> Product: ShowProduct / greet / interacción
        Product --> Product: swipe / carrito
        Product --> Attract: timeout de inactividad
        Product --> Idle: ShowIdle / proximity away
        Attract --> Idle: ShowIdle
        Idle --> Product: ShowProduct

        state Product {
            [*] --> Loading: HomeStatus.loading
            Loading --> Loaded: éxito
            Loading --> Error: fallo
            Error --> Loading: retry
            Loaded --> Loaded: polling sin cambios
            Loaded --> Loaded: polling con cambios
        }
    }

    Product --> PaymentPage: pagar carrito válido
    PaymentPage --> Attract: éxito + 5s
    PaymentPage --> Product: cancelar / back
    PaymentPage --> Idle: ShowIdle

    note right of PaymentPage
        QrPaymentPage es una ruta aparte,
        no un DisplayMode de Home.
        Sus estados están en QrPaymentStatus.
    end note
```

## PlantUML

```plantuml
@startuml
!theme plain
title Estados de interacción de la pantalla principal

state HomePage {
    [*] --> Idle
    Idle --> Attract : load OK / ShowAttract
    Attract --> Product : ShowProduct / greet / interacción
    Product --> Product : swipe / carrito
    Product --> Attract : timeout de inactividad
    Product --> Idle : ShowIdle / proximity away
    Attract --> Idle : ShowIdle
    Idle --> Product : ShowProduct

    state Product {
        [*] --> Loading : HomeStatus.loading
        Loading --> Loaded : éxito
        Loading --> Error : fallo
        Error --> Loading : retry
        Loaded --> Loaded : polling sin cambios
        Loaded --> Loaded : polling con cambios
    }
}

Product --> QrPaymentPage : pagar carrito válido
QrPaymentPage --> Attract : éxito + 5s
QrPaymentPage --> Product : cancelar / back
QrPaymentPage --> Idle : ShowIdle

note right of QrPaymentPage
    QrPaymentPage es una ruta aparte,
    no un DisplayMode de Home.
    Sus estados están en QrPaymentStatus.
end note

@enduml
```

## Cuándo actualizar

- Cuando se agregue un nuevo modo visual (`DisplayMode`).
- Cuando cambie la navegación entre pantallas o el timeout de inactividad.
- Cuando se incorpore un nuevo comando remoto que afecte la pantalla principal.
