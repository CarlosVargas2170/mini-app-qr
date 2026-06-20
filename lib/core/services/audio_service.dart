import 'package:audioplayers/audioplayers.dart';

/// Servicio para reproducir assets de audio con cooldown anti-spam.
///
/// Ideal para un bot físico manejado manualmente en un diner,
/// donde el operador pulsa un botón para saludar y el sistema
/// agradece automáticamente al completar el pago.
class AudioService {
  static DateTime? _lastPlayed;

  static Future<void> _play(String assetPath) async {
    // Cooldown de 5 segundos para evitar saturación de audio
    final now = DateTime.now();
    if (_lastPlayed != null &&
        now.difference(_lastPlayed!) < const Duration(seconds: 5)) {
      return;
    }
    _lastPlayed = now;

    final player = AudioPlayer();
    try {
      await player.play(AssetSource(assetPath));
      await player.onPlayerComplete.first;
    } catch (_) {
      // Ignorar errores de reproducción silenciosamente
    } finally {
      await player.dispose();
    }
  }

  /// Reproduce el saludo '¿deseas un café?'.
  /// Requiere: assets/audio/question.mp3
  static Future<void> playQuestion() async => _play('audio/question_coffe.wav');

  /// Reproduce el agradecimiento post-pago.
  /// Requiere: assets/audio/thanks.mp3
  static Future<void> playThanks() async => _play('audio/thanks_shopping.wav');
}
