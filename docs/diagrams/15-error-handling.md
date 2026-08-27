# Manejo de errores y recuperación

Describe las rutas de error principales del sistema y cómo la aplicación recupera o degradea gracefulmente.

## Mermaid

```mermaid
flowchart TD
    Start[Error] --> Type{Tipo}

    Type -- Carga inicial --> Retry{¿Quedan reintentos?}
    Retry -- Sí --> Wait[Esperar 2s]
    Wait --> RetryLoad[Reintentar carga]
    Retry -- No --> Partial{¿Algunos merchants cargaron?}
    Partial -- Sí --> PartialOK[Mostrar catálogo parcial]
    Partial -- No --> LoadError[HomeStatus.error + mensaje]

    Type -- Merchant individual --> FailGraceful[Devolver null]
    FailGraceful --> Continue[Continuar con otros merchants]

    Type -- Polling de productos --> Silent[Fallo silencioso]
    Silent --> Keep[Conservar catálogo actual]

    Type -- Producto no disponible pre-pago --> PayFailed[QrPaymentStatus.failed]
    Type -- Precio cambió --> UpdatePrice[Actualizar precio local]
    UpdatePrice --> Recalc[Recalcular total]
    Type -- Total inválido --> PayFailed
    Type -- Error creando orden/QR --> PayFailed

    Type -- Error HTTP en polling de pago --> Log[Loguear error]
    Log --> ContinuePoll[Continuar polling]

    Type -- Pago fallido por backend --> Clean[Limpiar orderId y qrBase64]
    Clean --> PayFailed

    Type -- completeOrder falla --> SuccessUI[UI sigue mostrando éxito]
    SuccessUI --> Observability[Requiere observabilidad externa]

    Type -- Servidor no puede iniciar --> LogServer[Loguear error]
    LogServer --> AppContinues[App gráfica continúa]
```

## PlantUML

```plantuml
@startuml
!theme plain
title Manejo de errores y recuperación

start
:Error;
if (Tipo) then (Carga inicial)
    if (¿Quedan reintentos?) then (sí)
        :Esperar 2s;
        :Reintentar carga;
    else (no)
        if (¿Algunos merchants cargaron?) then (sí)
            :Mostrar catálogo parcial;
        else (no)
            :HomeStatus.error + mensaje;
        endif
    endif
elseif (Merchant individual) then (sí)
    :Devolver null;
    :Continuar con otros merchants;
elseif (Polling de productos) then (sí)
    :Fallo silencioso;
    :Conservar catálogo actual;
elseif (Producto no disponible pre-pago) then (sí)
    :QrPaymentStatus.failed;
elseif (Precio cambió) then (sí)
    :Actualizar precio local;
    :Recalcular total;
elseif (Total inválido) then (sí)
    :QrPaymentStatus.failed;
elseif (Error creando orden/QR) then (sí)
    :QrPaymentStatus.failed;
elseif (Error HTTP en polling de pago) then (sí)
    :Loguear error;
    :Continuar polling;
elseif (Pago fallido por backend) then (sí)
    :Limpiar orderId y qrBase64;
    :QrPaymentStatus.failed;
elseif (completeOrder falla) then (sí)
    :UI sigue mostrando éxito;
    :Requiere observabilidad externa;
elseif (Servidor no puede iniciar) then (sí)
    :Loguear error;
    :App gráfica continúa;
endif

stop

@enduml
```

## Cuándo actualizar

- Cuando se agregue un servicio centralizado de logs o métricas.
- Cuando cambie la política de reintentos.
- Cuando se modifique el comportamiento ante `completeOrder` fallido.
