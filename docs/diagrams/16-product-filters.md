# Filtros y visibilidad de productos

Describe el orden de evaluación de `ProductFilterConfig` para decidir qué productos aparecen en el carrusel.

## Mermaid

```mermaid
flowchart TD
    Start[Producto del catálogo] --> Merchant{¿enabledMerchants no vacío
Y merchant no está incluido?}
    Merchant -- Sí --> Hide1[Ocultar]
    Merchant -- No --> Mode{filterMode}

    Mode -- whitelist --> Pinned1{¿productId en pinnedProducts?}
    Pinned1 -- Sí --> Show1[Mostrar]
    Pinned1 -- No --> Hide2[Ocultar]

    Mode -- blacklist --> Pinned2{¿productId en pinnedProducts?}
    Pinned2 -- Sí --> Show2[Mostrar]
    Pinned2 -- No --> Hidden{¿productId en hiddenProducts?}
    Hidden -- Sí --> Hide3[Ocultar]
    Hidden -- No --> Show3[Mostrar]

    Mode -- all --> Pinned3{¿productId en pinnedProducts?}
    Pinned3 -- Sí --> Show4[Mostrar]
    Pinned3 -- No --> Show5[Mostrar]

    API[POST /products/filter] --> Update[Actualizar ProductFilterConfig]
    Update --> Optional{reload?}
    Optional -- Sí --> Reload[Emitir ReloadProduct]
    Optional -- No --> Memory[Solo en memoria]
    Reset[POST /products/filter con reset=true] --> ResetAll[Resetear filtros a modo all]
```

## PlantUML

```plantuml
@startuml
!theme plain
title Filtros y visibilidad de productos

start
:Producto del catálogo;

if (¿enabledMerchants no vacío\nY merchant no está incluido?) then (sí)
    :Ocultar;
    stop
endif

if (filterMode) then (whitelist)
    if (¿productId en pinnedProducts?) then (sí)
        :Mostrar;
    else (no)
        :Ocultar;
    endif
elseif (blacklist) then (sí)
    if (¿productId en pinnedProducts?) then (sí)
        :Mostrar;
    elseif (¿productId en hiddenProducts?) then (sí)
        :Ocultar;
    else (no)
        :Mostrar;
    endif
else (all)
    :Mostrar;
endif

stop

start
:POST /products/filter;
:Actualizar ProductFilterConfig;
if (reload?) then (sí)
    :Emitir ReloadProduct;
else (no)
    :Solo en memoria;
endif
stop

start
:POST /products/filter con reset=true;
:Resetear filtros a modo all;
stop

@enduml
```

## Reglas de prioridad

1. Si `enabledMerchants` no está vacío y el merchant no está incluido, el producto se oculta.
2. En modo `whitelist`, solo se muestran productos en `pinnedProducts`.
3. Fuera de `whitelist`, un producto fijado se muestra incluso si está en `hiddenProducts`.
4. En modo `blacklist`, se ocultan los IDs en `hiddenProducts`.
5. En modo `all`, se muestra todo lo que haya superado la validación del merchant.

## Cuándo actualizar

- Cuando cambie el orden de evaluación.
- Cuando se agreguen nuevos modos de filtro.
- Cuando cambie la forma en que se aplican desde el endpoint.
