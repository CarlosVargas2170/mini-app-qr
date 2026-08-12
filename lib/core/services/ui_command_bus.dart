import 'dart:async';

/// Comandos que el servidor HTTP puede emitir hacia la capa de presentacion.
///
/// Desacopla AppServer (infraestructura) de los Cubits (presentacion)
/// respetando Clean Architecture.
///
/// Uso de sealed class en lugar de enum permite transportar datos
/// (ej: el assetPath del GIF a mostrar).
sealed class UiCommand {
  const UiCommand();
}

/// Mostrar video de atraccion (robot cerca de persona).
///
/// [gifAsset] permite elegir que GIF se muestra.
/// Si es null, se usa el GIF por defecto (`assets/images/normal.gif`).
class ShowAttract extends UiCommand {
  final String? gifAsset;
  const ShowAttract({this.gifAsset});
}

/// Mostrar producto (sin audio).
class ShowProduct extends UiCommand {
  const ShowProduct();
}

/// Volver a estado de reposo / espera (persona se alejo).
class ShowIdle extends UiCommand {
  const ShowIdle();
}

/// Recargar producto y merchant desde la API (config cambio).
class ReloadProduct extends UiCommand {
  const ReloadProduct();
}

/// Cancelar pago activo y volver al producto con timeout corto para attract.
class CancelPayment extends UiCommand {
  const CancelPayment();
}

/// Mostrar producto, reproducir saludo y resetear carrusel al primer elemento.
class ShowProductResetCarousel extends UiCommand {
  const ShowProductResetCarousel();
}

/// Iniciar polling del pago QR del producto visible en home (manual, operador).
class StartPaymentPolling extends UiCommand {
  const StartPaymentPolling();
}

/// Detener el polling del pago QR en home (sin cancelar la orden).
class StopPaymentPolling extends UiCommand {
  const StopPaymentPolling();
}

/// Forzar un poll de productos incondicional (ignora el umbral de staleness).
class ForceProductPoll extends UiCommand {
  const ForceProductPoll();
}

/// Consultar el estado actual del polling de productos.
class GetProductPollingStatus extends UiCommand {
  const GetProductPollingStatus();
}

/// Bus de eventos interno para comunicar capas sin importaciones cruzadas.
class UiCommandBus {
  static final StreamController<UiCommand> _controller =
      StreamController<UiCommand>.broadcast();

  static Stream<UiCommand> get stream => _controller.stream;

  static void emit(UiCommand cmd) => _controller.add(cmd);

  /// Nombre del GIF actualmente configurado (sin extension ni ruta).
  /// Se actualiza cada vez que se emite un [ShowAttract] con [ShowAttract.gifAsset].
  static String currentGifName = 'attract';
}
