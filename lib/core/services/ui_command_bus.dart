import 'dart:async';

/// Comandos que el servidor HTTP puede emitir hacia la capa de presentacion.
///
/// Desacopla AppServer (infraestructura) de los Cubits (presentacion)
/// respetando Clean Architecture.
enum UiCommand {
  /// Mostrar video de atraccion (robot cerca de persona).
  showAttract,

  /// Mostrar producto y reproducir saludo (operador pulso saludar).
  showProduct,

  /// Volver a estado de reposo / espera (persona se alejo).
  showIdle,
}

/// Bus de eventos interno para comunicar capas sin importaciones cruzadas.
class UiCommandBus {
  static final StreamController<UiCommand> _controller =
      StreamController<UiCommand>.broadcast();

  static Stream<UiCommand> get stream => _controller.stream;

  static void emit(UiCommand cmd) => _controller.add(cmd);
}
