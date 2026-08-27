# Configuración dinámica por HTTP

Muestra cómo `POST /config` modifica `AppSettings` en memoria y qué campos requieren reinicio, recarga o simplemente quedan aplicados.

## Mermaid

```mermaid
flowchart TD
    Start[POST /config] --> Parse[Parsear JSON]
    Parse --> Fields[Iterar campos enviados]

    Fields --> BaseUrl{baseUrl o bearerToken}
    BaseUrl -- Sí --> Apply1[Aplicar a AppSettings]
    Apply1 --> Restart1[needsRestart = true]

    Fields --> Vpn{baseUrlVpn o portVpn}
    Vpn -- Sí --> Apply2[Aplicar a AppSettings]
    Apply2 --> Restart2[needsRestart = true]

    Fields --> Merchant{merchantId, merchantIds o productId}
    Merchant -- Sí --> Apply3[Aplicar a AppSettings]
    Apply3 --> Reload[needsReload = true]

    Restart1 --> Response
    Restart2 --> Response
    Reload --> Bus[Emitir ReloadProduct]
    Bus --> Home[HomeCubit.load]

    Response[Responder JSON con updated, needsRestart, needsReload]

    Get[GET /config] --> Public[buildPublicConfigData]
    Public --> Omit[Omitir bearerToken y credenciales]
    Omit --> RespGet[Responder configuración pública]
```

## PlantUML

```plantuml
@startuml
!theme plain
title Configuración dinámica por HTTP

start
:POST /config;
:Parsear JSON;
:Iterar campos enviados;

if (baseUrl o bearerToken?) then (sí)
    :Aplicar a AppSettings;
    :needsRestart = true;
endif

if (baseUrlVpn o portVpn?) then (sí)
    :Aplicar a AppSettings;
    :needsRestart = true;
endif

if (merchantId, merchantIds o productId?) then (sí)
    :Aplicar a AppSettings;
    :needsReload = true;
    :Emitir ReloadProduct;
    :HomeCubit.load();
endif

:Responder JSON con updated, needsRestart, needsReload;

stop

start
:GET /config;
:buildPublicConfigData;
:Omitir bearerToken y credenciales;
:Responder configuración pública;
stop

@enduml
```

## Limitaciones importantes

- Los cambios **no se persisten en disco**.
- `ConfigStorage` existe pero no participa actualmente en `AppSettings.load()` ni en `POST /config`.
- Cambiar `baseUrl`, `bearerToken`, `baseUrlVpn` o `portVpn` requiere reiniciar la app porque los clientes Dio y el socket ya fueron creados.
- Cambiar `merchantId`, `merchantIds` o `productId` dispara `ReloadProduct`.

## Cuándo actualizar

- Cuando se implemente persistencia real de configuración.
- Cuando se permita modificar más campos en runtime.
- Cuando se reconstruyan clientes Dio sin reinicio.
