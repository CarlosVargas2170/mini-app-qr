# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es/1.0.0/)
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Added

- Soporte de facturación por merchant mediante `billingType`.
- Diálogo de facturación (`BillingFlowDialog`) en el flujo de pago QR para recopilar NIT y razón social opcionales.
- Propagación de datos de facturación (`nit`, `businessName`) en el payload de `POST /orders/create-pending`.
- Campo `billingType` en `MerchantConfig`, `Merchant` y ambos data sources (`LegacyProductDataSource`, `EcosystemProductDataSource`).
- Getter `Merchant.usesBilling` para determinar si un comercio requiere facturación.
- Método `HomeState.merchantUsesBilling(int)` para consultar la política de facturación de un merchant específico.
- Logs de diagnóstico en `LegacyProductDataSource` y `EcosystemProductDataSource` para datos obtenidos de cada merchant.
- Pruebas unitarias para `MerchantConfigFactory` (normalización de `billingType`) y `Merchant.usesBilling`.
- Pruebas de widget para `BillingFlowDialog`.

### Changed

- `HomePage._onPayPressed` ahora muestra `BillingFlowDialog` condicionalmente según `merchantUsesBilling` del primer producto del carrito.
- `ProductDataSourceFactory` pasa `billingType` al construir `LegacyProductDataSource` y `EcosystemProductDataSource`.
- Documentación actualizada: `PAYMENT.md`, `FLOWS.md`, `STATE_MANAGEMENT.md`, `ARCHITECTURE.md`, `API.md`, `CATALOG.md` y diagramas de secuencia.

## [1.0.0] - 2026-08-28

### Added

- Catálogo multi-merchant con soporte para proveedores Legacy (`patio_service`) y Ecosystem (`merchant_panel`).
- Pago QR con generación de orden, código QR y polling de estado.
- Servidor HTTP local (`AppServer`) para control remoto, audio, filtros de productos y configuración dinámica.
- Sistema de audio con cooldown, overlays y reproducción de assets predefinidos.
- Filtros dinámicos de productos (`all`, `blacklist`, `whitelist`).
- Polling bajo demanda de productos con reconciliación de carrito.
- Modos visuales de la pantalla principal: `idle`, `attract`, `product`.
- Carrito flotante con selector de cantidad y cálculo de totales.
- Caché de data sources por merchant y caché global de catálogo (`ProductCache`).
- Despliegue Linux con scripts de empaquetado y modo kiosco.
- Documentación técnica completa en `docs/` con diagramas Mermaid.
