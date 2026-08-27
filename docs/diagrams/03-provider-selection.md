# Selección dinámica de proveedor de productos

Describe cómo `ProductRepositoryImpl` decide entre `LegacyProductDataSource` y `EcosystemProductDataSource` para cada merchant, con `ProductDataSourceFactory` y `MerchantConfigFactory`.

## Mermaid

```mermaid
flowchart TD
    Start[Solicitud por merchantId] --> Cached{Data source en caché?}
    Cached -- Sí --> Use[Reutilizar data source]
    Cached -- No --> Repo[ProductRepositoryImpl]
    Repo --> Factory[ProductDataSourceFactory]
    Factory --> MerchantFactory[MerchantConfigFactory]
    MerchantFactory --> Config[GET /merchants/{id}]
    Config --> System{externalSystem == patio_service?}
    System -- Sí --> Legacy[Crear LegacyProductDataSource]
    System -- No --> Ecosystem[Crear EcosystemProductDataSource]
    Legacy --> Store[Guardar por merchantId en caché interna]
    Ecosystem --> Store
    Store --> Use
    Use --> Operation[getProducts / getProduct / getMerchantInfo]

    subgraph LegacyAPI
        L1[GET /v1/merchants/{id}/products-categories]
        L2[GET /v1/merchants/{id}/products/{productId}]
        L3[GET /merchants/{id}]
    end

    subgraph EcosystemAPI
        E1[GET /ecosystem/companies/{companyId}/channels/{channelId}/menu]
        E2[Descartar ítems inactive]
        E3[Buscar producto en menú descargado]
    end

    Legacy --> LegacyAPI
    Ecosystem --> EcosystemAPI
```

## PlantUML

```plantuml
@startuml
!theme plain
title Selección dinámica de proveedor de productos

start
:Solicitud por merchantId;
if (Data source en caché?) then (Sí)
    :Reutilizar data source;
else (No)
    :ProductRepositoryImpl;
    :ProductDataSourceFactory;
    :MerchantConfigFactory;
    :GET /merchants/{id};
    if (externalSystem == patio_service?) then (Sí)
        :Crear LegacyProductDataSource;
    else (No)
        :Crear EcosystemProductDataSource;
    endif
    :Guardar por merchantId en caché interna;
endif
:Operation:\ngetProducts / getProduct / getMerchantInfo;
stop

partition "Legacy" {
    :GET /v1/merchants/{id}/products-categories;
    :GET /v1/merchants/{id}/products/{productId};
    :GET /merchants/{id};
}

partition "Ecosystem" {
    :GET /ecosystem/companies/{companyId}/channels/{channelId}/menu;
    :Descartar ítems inactive;
    :Buscar producto en menú descargado;
}

@enduml
```

## Cuándo actualizar

- Cuando se agregue un tercer proveedor de catálogos.
- Cuando cambie la lógica de detección (por ejemplo, ya no se use `patio_service`).
- Cuando se modifique la estrategia de cacheo de data sources.
- Cuando cambien las rutas de Ecosystem o Legacy.
