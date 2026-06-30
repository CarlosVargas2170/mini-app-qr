import 'dart:async';

/// Servicio para notificar cuando se reproduce audio.
/// Permite que los widgets se suscriban a eventos de audio.
class AudioNotificationService {
  static final _controller = StreamController<AudioEvent>.broadcast();
  
  /// Stream de eventos de audio.
  static Stream<AudioEvent> get onAudioEvent => _controller.stream;
  
  /// Notifica que se está reproduciendo un audio.
  static void notifyPlaying(String audioName, {String? displayText}) {
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
  
  /// Obtiene el texto a mostrar basado en el nombre del audio.
  static String _getDisplayText(String audioName) {
    switch (audioName) {
      case 'audio/question_coffe.wav':
        return '¿Deseas un café?';
      case 'audio/thanks_shopping.wav':
        return '¡Gracias por tu compra!';
      case 'audio/purchase_buy.wav':
        return '¡Invitación a comprar!';
      case 'audio/there _is_an_order.wav':
        return '¡Orden recibida!';
      case 'audio/attention_excuse_me.wav':
        return 'Atención, disculpe';
      case 'audio/collect_tray.wav':
        return 'Cobrar bandeja';
      case 'audio/here_is_coffee.wav':
        return '¡Aquí está tu café!';
      default:
        return audioName;
    }
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