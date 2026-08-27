# Flujo del carrito

Describe cómo el usuario gestiona cantidades, límites, vaciado y preparación del carrito antes del pago.

## Mermaid

```mermaid
flowchart TD
    Start[Producto visible en carrusel] --> Inc{Incrementar}
    Inc -- Sí --> Max{¿Cantidad < maxCartItemQuantity?}
    Max -- Sí --> Add[Incrementar cantidad]
    Max -- No --> Inc
    Add --> Recalc[Recalcular unidades y total]
    Add --> ResetTimer[Reiniciar timeout de sesión]

    Start --> Dec{Decrementar}
    Dec -- Sí --> Zero{¿Cantidad == 1?}
    Zero -- Sí --> Remove[Eliminar entrada del carrito]
    Zero -- No --> Sub[Decrementar cantidad]
    Sub --> Recalc
    Remove --> Recalc

    Start --> Del{Eliminar}
    Del -- Sí --> Remove

    Start --> Clear{Vaciar carrito}
    Clear -- Sí --> Confirm{Confirmar?}
    Confirm -- Sí --> Empty[Vaciar todas las cantidades]
    Empty --> Recalc

    Recalc --> Pay{Pagar}
    Pay -- Sí --> Validate{¿Carrito no vacío?}
    Validate -- Sí --> Pause[Pausar timeout]
    Pause --> Force[forcePoll productos]
    Force --> Consistent{¿Carrito cambió o quedó vacío?}
    Consistent -- Sí --> Resume[Reanudar timeout + aviso]
    Consistent -- No --> Navigate[Navegar a QrPaymentPage]
```

## PlantUML

```plantuml
@startuml
!theme plain
title Flujo del carrito

start
:Producto visible en carrusel;

if (Incrementar?) then (sí)
    if (¿Cantidad < maxCartItemQuantity?) then (sí)
        :Incrementar cantidad;
    else (no)
        :Ignorar;
    endif
elseif (Decrementar?) then (sí)
    if (¿Cantidad == 1?) then (sí)
        :Eliminar entrada del carrito;
    else (no)
        :Decrementar cantidad;
    endif
elseif (Eliminar?) then (sí)
    :Eliminar entrada del carrito;
elseif (Vaciar carrito?) then (sí)
    if (Confirmar?) then (sí)
        :Vaciar todas las cantidades;
    endif
endif

:Recalcular unidades y total;
:Reiniciar timeout de sesión;

if (Pagar?) then (sí)
    if (¿Carrito no vacío?) then (sí)
        :Pausar timeout;
        :forcePoll productos;
        if (¿Carrito cambió o quedó vacío?) then (sí)
            :Reanudar timeout + aviso;
        else (no)
            :Navegar a QrPaymentPage;
        endif
    endif
endif

stop

@enduml
```

## Detalles de implementación

- Las cantidades se almacenan con clave `merchantId_productId`.
- `maxCartItemQuantity` viene de `AppSettings`.
- El carrito se vacía al entrar en `DisplayMode.attract` o `DisplayMode.idle`.
- `load()` reinicia el carrito; `_pollProducts()` lo reconcilia.

## Cuándo actualizar

- Cuando cambie la clave del carrito o el límite máximo.
- Cuando se agregue confirmación en otras operaciones.
- Cuando cambie la preparación previa al pago.
