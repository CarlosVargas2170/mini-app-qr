# Mini App QR

Aplicación Flutter de autoservicio/tótem para pantalla completa. Muestra un catálogo de productos multi-merchant, permite seleccionar ítems y gestiona el pago mediante código QR. Incluye un servidor HTTP local para control remoto desde robots, controladores físicos o servicios VPN.

## Tecnologías

- **Flutter** + **Dart 3** (desktop, orientado a Linux)
- **flutter_bloc** (Cubits) + **equatable**
- **dio** (cliente HTTP)
- **flutter_dotenv** (variables de entorno)
- **audioplayers** + **window_manager**
- **carousel_slider** + **cached_network_image** (carrusel e imágenes)

## Requisitos

- **Flutter** `3.44.3` (stable) — Dart `3.12.2` — DevTools `2.57.0`
- Dependencias de escritorio de la plataforma
- Archivo `.env` creado desde `.env_example`
- Acceso de red a las APIs configuradas

> Versión del SDK verificada en el entorno de desarrollo principal. Compila para Windows (desarrollo) y Linux (producción/kiosco).

## Instalación y ejecución local

```powershell
flutter pub get
flutter run -d windows
```

## Comandos de desarrollo

```powershell
flutter analyze
flutter test
dart format lib test
```

## Estructura del proyecto

```text
lib/
├── core/        # Configuración, inyección, servicios compartidos
├── data/        # Data sources, DTOs, repositorios
├── domain/      # Entidades, contratos, casos de uso
├── presentation/# Pages, widgets, Cubits
└── main.dart
```

## Documentación

La documentación técnica vive en `docs/`:

| Documento | Contenido |
| --- | --- |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Visión de alto nivel, capas, modelo de dominio |
| [docs/FLOWS.md](docs/FLOWS.md) | Inventario de flujos del sistema |
| [docs/CATALOG.md](docs/CATALOG.md) | Productos, proveedores, filtros |
| [docs/PAYMENT.md](docs/PAYMENT.md) | Pago QR, polling, panel embebido |
| [docs/API.md](docs/API.md) | Endpoints del servidor local y APIs externas |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Variables de entorno y seguridad |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Build Linux, kiosco e instalación |
| [docs/AUDIO.md](docs/AUDIO.md) | Sistema de audio |
| [docs/diagrams/](docs/diagrams/) | Diagramas Mermaid |

Para orientación rápida, comienza por [docs/README.md](docs/README.md).

## Seguridad básica

- No versionar `.env`, tokens ni credenciales.
- El servidor HTTP interno no usa autenticación ni TLS; exponer solo en VPN o segmento controlado.
- Consulta [docs/CONFIGURATION.md](docs/CONFIGURATION.md) para más detalles.
