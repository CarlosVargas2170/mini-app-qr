import 'dart:async';

/// Servicio para notificar cuando se reproduce audio.
/// Permite que los widgets se suscriban a eventos de audio.
class AudioNotificationService {
  static final _controller = StreamController<AudioEvent>.broadcast();

  /// Stream de eventos de audio.
  static Stream<AudioEvent> get onAudioEvent => _controller.stream;

  /// Notifica que se está reproduciendo un audio.
  static void notifyPlaying(String audioName, {String? displayText, bool showOverlay = true}) {
    if(!showOverlay) return; 
    _controller.add(AudioEvent(
      type: AudioEventType.playing,
      audioName: audioName,
      displayText: displayText ?? _getDisplayText(audioName),
    ));
  }

  /// Notifica que el audio terminó.
  static void notifyStopped() {
    _controller.add(AudioEvent(type: AudioEventType.stopped));
  }

  /// Obtiene un texto legible a partir del nombre del archivo de audio.
  ///
  /// Limpia el prefijo `audio/`, la extensión `.wav` y reemplaza `_` por espacios.
  /// Si el remote-control envía [displayText], se usa ese en su lugar.
  static String _getDisplayText(String audioName) {
    return audioName
        .replaceAll(RegExp(r'^audio/'), '')
        .replaceAll('.wav', '')
        .replaceAll('_', ' ');
  }

  /// Limpia los recursos.
  static void dispose() {
    _controller.close();
  }
}

/// Tipos de eventos de audio.
enum AudioEventType {
  playing,
  stopped,
}

/// Evento de audio.
class AudioEvent {
  final AudioEventType type;
  final String? audioName;
  final String? displayText;

  const AudioEvent({
    required this.type,
    this.audioName,
    this.displayText,
  });
}
