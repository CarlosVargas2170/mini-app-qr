# Documentación de Mini App QR

Esta carpeta contiene la documentación técnica del proyecto **Mini App QR**, una aplicación Flutter de autoservicio/tótem con catálogo multi-merchant y pago por QR.

## Mapa de documentación

| Documento | Dirigido a | Contenido |
| --- | --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Desarrolladores nuevos, arquitectos | Visión de alto nivel, capas, dependencias, modelo de dominio y decisiones técnicas. |
| [FLOWS.md](FLOWS.md) | Desarrolladores, QA, soporte | Inventario numerado de los 35 flujos del sistema, incluyendo alertas operativas. |
| [STATE_MANAGEMENT.md](STATE_MANAGEMENT.md) | Desarrolladores frontend | Cubits, estados, transiciones, carrito, comandos de UI y ciclo de vida. |
| [CATALOG.md](CATALOG.md) | Desarrolladores backend/frontend | Carga de productos, proveedores Legacy/Ecosystem, filtros, cachés y polling de catálogo. |
| [PAYMENT.md](PAYMENT.md) | Desarrolladores backend/frontend | Flujo QR completo: validación, generación, polling, confirmación, panel embebido y cancelación. |
| [API.md](API.md) | Integradores, operadores | Endpoints del servidor HTTP local y contratos de las APIs externas. |
| [CONFIGURATION.md](CONFIGURATION.md) | DevOps, operadores | Variables de entorno, fallbacks, configuración dinámica y seguridad. |
| [AUDIO.md](AUDIO.md) | Desarrolladores, integradores | Sistema de audio, cooldown, overlays y endpoints relacionados. |
| [DEPLOYMENT.md](DEPLOYMENT.md) | DevOps, operadores | Build, empaquetado, instalación Linux, modo kiosco y verificación. |
| `diagrams/` | Todos | Diagramas de arquitectura, secuencia, estados y flujos en formato Mermaid. |

## Diagramas disponibles

Los diagramas están organizados por prioridad y numerados para facilitar su ubicación. Cada archivo contiene tanto el código Mermaid como el código PlantUML equivalente:

1. [Arquitectura y dependencias principales](diagrams/01-system-overview.md)
2. [Arranque y carga inicial del catálogo](diagrams/02-boot-sequence.md)
3. [Selección dinámica de proveedor](diagrams/03-provider-selection.md)
4. [Estados de interacción de la pantalla principal](diagrams/04-home-states.md)
5. [Pago QR: validación, generación y confirmación](diagrams/05-payment-sequence.md)
6. [Servidor local y bus de comandos](diagrams/06-server-commands.md)
7. [Panel QR embebido y caché](diagrams/07-embedded-qr.md)
8. [Polling de productos y reconciliación del carrito](diagrams/08-product-polling.md)
9. [Comparación de flujos de pago](diagrams/09-payment-flows-comparison.md)
10. [Flujo del carrito](diagrams/10-cart-flow.md)
11. [Configuración dinámica por HTTP](diagrams/11-dynamic-config.md)
12. [Estado remoto del pago y contador](diagrams/12-payment-remote-status.md)
13. [Sistema de audio](diagrams/13-audio-flow.md)
14. [Despliegue Linux y modo kiosco](diagrams/14-linux-deployment.md)
15. [Manejo de errores y recuperación](diagrams/15-error-handling.md)
16. [Filtros y visibilidad de productos](diagrams/16-product-filters.md)

> **Prioridad sugerida de mantenimiento:** mantener primero los diagramas de pago (5, 9), arquitectura (1) y estados de Home (4), porque son los flujos críticos para operación y soporte. Actualizar proveedor (3), catálogo (2, 8, 10, 16), servidor (6, 11, 12) y despliegue (14) cuando cambien endpoints, reglas de cacheo o procedimientos operativos.

## Convenciones

- Los diagramas usan [Mermaid](https://mermaid.js.org/) y pueden visualizarse en GitHub, GitLab o en un editor compatible.
- Las rutas relativas entre documentos funcionan desde la raíz del repositorio.
- Si falta información, se indica explícitamente en el documento correspondiente.
