# Polling de productos y reconciliación del carrito

Flujo de decisión cuando se solicita mostrar el catálogo o se fuerza un polling de productos, incluyendo reconciliación del carrito y diferencias entre `load()` y `_pollProducts()`.

## Mermaid

```mermaid
flowchart TD
    Start{Origen}
    Start -- load / ReloadProduct --> Load[load completo]
    Start -- showProduct / ForceProductPoll --> Poll[Intentar poll]

    Load --> LoadRetry[Hasta 2 intentos con reintento a los 2s]
    LoadRetry --> LoadPartial{Fallo parcial?}
    LoadPartial -- merchants parciales --> Cache1[Actualizar ProductCache]
    LoadPartial -- todos fallan --> LoadError[HomeStatus.error]
    Cache1 --> ResetCart[Vaciar carrito]
    ResetCart --> Apply1[Aplicar filtros]
    Apply1 --> Attract[DisplayMode.attract]

    Poll --> Threshold{Datos stale?}
    Threshold -- No --> Keep[Mantener catálogo y timestamp]
    Threshold -- Sí --> Fetch[Cargar merchants en paralelo]
    Fetch --> Apply2[Aplicar filtros]
    Apply2 --> Compare{¿Cambió lista o carrito?}
    Compare -- No --> UpdateTs[Actualizar timestamp interno]
    Compare -- Sí --> Reconcile[Reconciliar carrito]
    Reconcile --> Removed[Eliminar productos ausentes]
    Reconcile --> Price[Conservar cantidad y avisar cambio de precio]
    Removed --> Cache2[Actualizar ProductCache/HomeState]
    Price --> Cache2
    Cache2 --> Snack[SnackBar si displayMode == product]
    Fetch -. error .-> Keep
```

## PlantUML

```plantuml
@startuml
!theme plain
title Polling de productos y reconciliación del carrito

start
if (Origen) then (load / ReloadProduct)
    :load() completo;
    repeat
        :Cargar merchants en paralelo;
    repeat while (fallo total y quedan reintentos?) is (sí)
    if (fallo parcial?) then (sí)
        :Actualizar ProductCache;
        :Vaciar carrito;
        :Aplicar filtros;
        :DisplayMode.attract;
    else (todos fallaron)
        :HomeStatus.error;
    endif
else (showProduct / ForceProductPoll)
    :Intentar poll;
    if (Datos stale?) then (Sí)
        :Cargar merchants en paralelo;
        :Aplicar filtros;
        if (¿Cambió lista o carrito?) then (Sí)
            :Reconciliar carrito;
            fork
                :Eliminar productos ausentes;
            fork again
                :Conservar cantidad y avisar cambio de precio;
            end fork
            :Actualizar ProductCache/HomeState;
            :SnackBar si displayMode == product;
        else (No)
            :Actualizar timestamp interno;
        endif
    else (No)
        :Mantener catálogo y timestamp;
    endif
endif

stop

@enduml
```

## Diferencia clave entre `load()` y `_pollProducts()`

| Aspecto | `load()` | `_pollProducts()` |
|---|---|---|
| Reinicio de carrito | Sí, vacía el carrito | No, reconcilia conservando cantidades |
| Modo visual final | `attract` | Conserva el actual |
| Reintentos | Sí, hasta 2 intentos | Sí, usa `_loadWithRetry()` |
| Error | Emite `HomeStatus.error` | Fallo silencioso, conserva estado anterior |
| SnackBar | No | Sí, si hay cambios y está en modo `product` |
| Timestamp | Actualiza `_lastPollTimestamp` | Actualiza `_lastPollTimestamp` |

## Cuándo actualizar

- Cuando cambie el umbral de staleness (`PRODUCT_POLLING_STALE_SECONDS`).
- Cuando se modifique la lógica de reconciliación.
- Cuando se agregue un nuevo paso al flujo de refresco del catálogo.
- Cuando cambie la política de reintentos.
