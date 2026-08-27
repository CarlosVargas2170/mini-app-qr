# Secuencia de arranque y carga inicial del catálogo

Ilustra el orden de inicialización desde `main.dart` hasta que la interfaz muestra el catálogo filtrado, incluyendo reintentos y fallos parciales.

## Mermaid

```mermaid
sequenceDiagram
    participant Main as main.dart
    participant WM as window_manager
    participant Env as .env
    participant Settings as AppSettings
    participant DI as ServiceLocator
    participant HTTP as AppServer
    participant UI as HomePage
    participant Home as HomeCubit
    participant Repo as ProductRepositoryImpl
    participant APIs as APIs de merchants
    participant Cache as ProductCache

    Main->>Main: WidgetsFlutterBinding.ensureInitialized()
    Main->>WM: ensureInitialized()
    Main->>WM: Configurar ventana fullscreen
    Main->>Env: dotenv.load(".env")
    Main->>Settings: load() (con fallbacks)
    Main->>DI: init()
    Main->>HTTP: start() sin await
    Main->>UI: runApp(HomePage)
    UI->>Home: Crear Cubit
    Home->>Home: Emitir loading

    loop Hasta 2 intentos (inicial + 1 reintento)
        Home->>Home: Leer MERCHANT_IDS
        par Por cada merchant configurado
            Home->>Repo: getProducts(merchantId)
            Repo->>APIs: Resolver proveedor y consultar catálogo
            APIs-->>Repo: Productos o null (fallo graceful)
            Home->>Repo: getMerchantInfo(merchantId)
            Repo->>APIs: Consultar información
            APIs-->>Repo: Merchant o null
        end
        alt Todos los merchants fallaron
            Home->>Home: Reintentar tras 2s
        else Al menos un merchant exitoso
            Home->>Cache: Guardar catálogo sin filtrar
            Home->>Home: Aplicar filtros
            Home-->>UI: loaded + attract
            Note over Home: Fin del arranque
        end
    end
    alt Agotados intentos
        Home-->>UI: error
    end
```

## PlantUML

```plantuml
@startuml
!theme plain
title Secuencia de arranque y carga inicial del catálogo

actor main.dart as Main
participant window_manager as WM
participant ".env" as Env
participant AppSettings as Settings
participant ServiceLocator as DI
participant AppServer as HTTP
participant HomePage as UI
participant HomeCubit as Home
participant ProductRepositoryImpl as Repo
participant "APIs de merchants" as APIs
participant ProductCache as Cache

Main -> Main : WidgetsFlutterBinding.ensureInitialized()
Main -> WM : ensureInitialized()
Main -> WM : Configurar ventana fullscreen
Main -> Env : dotenv.load(".env")
Main -> Settings : load() (con fallbacks)
Main -> DI : init()
Main -> HTTP : start() sin await
Main -> UI : runApp(HomePage)
UI -> Home : Crear Cubit
Home -> Home : Emitir loading

loop Hasta 2 intentos (inicial + 1 reintento)
    Home -> Home : Leer MERCHANT_IDS
    par Por cada merchant configurado
        Home -> Repo : getProducts(merchantId)
        Repo -> APIs : Resolver proveedor y consultar catálogo
        APIs --> Repo : Productos o null (fallo graceful)
        Home -> Repo : getMerchantInfo(merchantId)
        Repo -> APIs : Consultar información
        APIs --> Repo : Merchant o null
    end
    alt Todos los merchants fallaron
        Home -> Home : Reintentar tras 2s
    else Al menos un merchant exitoso
        Home -> Cache : Guardar catálogo sin filtrar
        Home -> Home : Aplicar filtros
        Home --> UI : loaded + attract
        note over Home : Fin del arranque
    end
end
alt Agotados intentos
    Home --> UI : error
end

@enduml
```

## Cuándo actualizar

- Cuando cambie el orden de arranque en `main.dart`.
- Cuando se agregue una nueva fuente de configuración o persistencia real en disco.
- Cuando el paralelismo de carga de merchants cambie de comportamiento.
- Cuando cambie la política de reintentos o fallos parciales.
