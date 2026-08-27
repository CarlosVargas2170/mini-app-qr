# Diagrama de arquitectura y dependencias principales

Muestra cómo se relacionan las capas internas (Presentation, Domain, Data), los servicios compartidos (Core), las APIs externas y el servidor HTTP local con sus consumidores.

## Mermaid

```mermaid
flowchart LR
    subgraph Clientes
        User[Usuario en tótem]
        Remote[Robot / operador / servicio VPN]
    end

    subgraph Presentation
        Home[HomePage]
        PaymentPage[QrPaymentPage]
        Panel[ProductQrPanelWrapper]
        Widgets[Widgets de carrusel, audio, QR]
        HC[HomeCubit]
        PC[QrPaymentCubit]
    end

    subgraph Domain
        UC[Casos de uso]
        Entities[Entidades Product, Merchant, Order]
        Contracts[Contratos de repositorio]
    end

    subgraph Data
        PR[ProductRepositoryImpl]
        QR[QrPaymentRepositoryImpl]
        Factory[ProductDataSourceFactory]
        MerchantFactory[MerchantConfigFactory]
        Legacy[LegacyProductDataSource]
        Eco[EcosystemProductDataSource]
        PaymentDS[QrPaymentRemoteDataSource]
    end

    subgraph Core
        Server[AppServer HTTP local]
        Bus[UiCommandBus]
        Settings[AppSettings]
        PCache[ProductCache]
        PStatus[PaymentPollingStatus]
        Counter[PaymentCounter]
        Audio[AudioService]
        AudioNotif[AudioNotificationService]
    end

    subgraph APIs
        LegacyApi[API Legacy]
        EcoApi[API Ecosystem]
        OrdersApi[API Órdenes y pagos QR]
    end

    User --> Home
    Remote --> Server

    Home --> HC
    PaymentPage --> PC
    Panel --> PC
    HC --> UC
    PC --> UC
    UC --> Contracts
    Contracts --> PR
    Contracts --> QR

    PR --> Factory
    Factory --> MerchantFactory
    MerchantFactory --> Legacy
    MerchantFactory --> Eco
    Legacy --> LegacyApi
    Eco --> EcoApi
    QR --> PaymentDS
    PaymentDS --> OrdersApi

    PR --> PCache
    HC --> PCache
    Server --> PCache
    Server --> PStatus
    Server --> Counter
    Panel --> PStatus
    Panel --> Counter
    PC --> PStatus

    Server --> Audio
    Home --> Audio
    PaymentPage --> Audio
    Panel --> Audio
    Audio --> AudioNotif
    AudioNotif --> Widgets

    Server --> Bus
    Bus --> Home
    Bus --> Panel

    Settings -.-> Server
    Settings -.-> Factory
    Settings -.-> PaymentDS
```

## PlantUML

```plantuml
@startuml
!theme plain
skinparam componentStyle rectangle

title Arquitectura y dependencias principales

package "Clientes" {
    actor "Usuario en tótem" as User
    actor "Robot / operador / VPN" as Remote
}

package "Presentation" {
    [HomePage] as Home
    [QrPaymentPage] as PaymentPage
    [ProductQrPanelWrapper] as Panel
    [Widgets de carrusel, audio, QR] as Widgets
    [HomeCubit] as HC
    [QrPaymentCubit] as PC
}

package "Domain" {
    [Casos de uso] as UC
    [Entidades Product, Merchant, Order] as Entities
    [Contratos de repositorio] as Contracts
}

package "Data" {
    [ProductRepositoryImpl] as PR
    [QrPaymentRepositoryImpl] as QR
    [ProductDataSourceFactory] as Factory
    [MerchantConfigFactory] as MerchantFactory
    [LegacyProductDataSource] as Legacy
    [EcosystemProductDataSource] as Eco
    [QrPaymentRemoteDataSource] as PaymentDS
}

package "Core" {
    [AppServer HTTP local] as Server
    [UiCommandBus] as Bus
    [AppSettings] as Settings
    [ProductCache] as PCache
    [PaymentPollingStatus] as PStatus
    [PaymentCounter] as Counter
    [AudioService] as Audio
    [AudioNotificationService] as AudioNotif
}

package "APIs externas" {
    [API Legacy] as LegacyApi
    [API Ecosystem] as EcoApi
    [API Órdenes y pagos QR] as OrdersApi
}

User --> Home
Remote --> Server

Home --> HC
PaymentPage --> PC
Panel --> PC
HC --> UC
PC --> UC
UC --> Contracts
Contracts --> PR
Contracts --> QR

PR --> Factory
Factory --> MerchantFactory
MerchantFactory --> Legacy
MerchantFactory --> Eco
Legacy --> LegacyApi
Eco --> EcoApi
QR --> PaymentDS
PaymentDS --> OrdersApi

PR --> PCache
HC --> PCache
Server --> PCache
Server --> PStatus
Server --> Counter
Panel --> PStatus
Panel --> Counter
PC --> PStatus

Server --> Audio
Home --> Audio
PaymentPage --> Audio
Panel --> Audio
Audio --> AudioNotif
AudioNotif --> Widgets

Server --> Bus
Bus --> Home
Bus --> Panel

Settings ..> Server : config
Settings ..> Factory : config
Settings ..> PaymentDS : config

@enduml
```

## Cuándo actualizar

- Cuando se agregue o elimine una capa, un servicio compartido o una API externa.
- Cuando cambie la forma en que `AppServer` publica comandos.
- Cuando se incorpore un nuevo consumidor remoto (por ejemplo, un nuevo tipo de robot).
- Cuando cambie la relación entre `ProductRepositoryImpl`, `ProductDataSourceFactory` y `MerchantConfigFactory`.
