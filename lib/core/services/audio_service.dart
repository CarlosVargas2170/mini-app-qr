import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Servicio para reproducir assets de audio con cooldown anti-spam.
///
/// Ideal para un bot fisico manejado manualmente en un diner,
/// donde el operador pulsa un boton para saludar y el sistema
/// agradece automaticamente al completar el pago.
class AudioService {
  static DateTime? _lastPlayed;
  static AudioPlayer? _currentPlayer;

  /// Cooldown configurable entre reproducciones (por defecto 5 segundos).
  static Duration cooldown = const Duration(seconds: 5);

  /// Reproduce un asset de audio.
  ///
  /// - [assetPath]: ruta relativa dentro de `assets/`. Ej: `audio/saludo.wav`.
  /// - [force]: si es `true`, ignora el cooldown.
  /// - [volume]: volumen entre 0.0 y 1.0 (por defecto 1.0).
  ///
  /// Retorna `true` si se reprodujo, `false` si se bloqueo por cooldown.
  static Future<bool> play(
    String assetPath, {
    bool force = false,
    double volume = 1.0,
  }) async {
    final now = DateTime.now();

    // Cooldown anti-spam
    if (!force &&
        _lastPlayed != null &&
        now.difference(_lastPlayed!) < cooldown) {
      final remaining = cooldown - now.difference(_lastPlayed!);
      debugPrint('[AudioService] Cooldown activo. Faltan ${remaining.inSeconds}s para "$assetPath"');
      return false;
    }
    _lastPlayed = now;

    // Detener reproduccion anterior si existe
    await stop();

    final player = AudioPlayer();
    _currentPlayer = player;

    try {
      debugPrint('[AudioService] Reproduciendo: $assetPath (volume=$volume)');
      await player.setVolume(volume);
      await player.play(AssetSource(assetPath));
      await player.onPlayerComplete.first;
      debugPrint('[AudioService] Finalizado: $assetPath');
      return true;
    } catch (e, stack) {
      debugPrint('[AudioService] ERROR reproduciendo "$assetPath": $e');
      debugPrint('[AudioService] StackTrace: $stack');
      return false;
    } finally {
      await player.dispose();
      if (_currentPlayer == player) {
        _currentPlayer = null;
      }
    }
  }

  /// Detiene cualquier audio que este sonando actualmente.
  static Future<void> stop() async {
    if (_currentPlayer != null) {
      debugPrint('[AudioService] Deteniendo reproduccion activa');
      await _currentPlayer!.stop();
      await _currentPlayer!.dispose();
      _currentPlayer = null;
    }
  }

  /// Reproduce el saludo 'deseas un cafe?'.
  static Future<bool> playQuestion({bool force = false}) async =>
      play('audio/question_coffe_old2.wav', force: force);

  /// Reproduce el agradecimiento post-pago.
  static Future<bool> playThanks({bool force = false}) async =>
      play('audio/thanks_shopping.wav', force: force);

  /// Reproduce el audio de invitacion a comprar.
  /// Cambia el asset si tu archivo tiene otro nombre.
  static Future<bool> playBuy({bool force = false}) async =>
      play('audio/purchase_buy.wav', force: force);
}
