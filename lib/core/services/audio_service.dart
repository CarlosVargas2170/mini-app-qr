import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../constants/audio_messages.dart';
import 'audio_notification_service.dart';

/// Servicio para reproducir assets de audio con cooldown anti-spam.
///
/// Ideal para un bot fisico manejado manualmente en un diner,
/// donde el operador pulsa un boton para saludar y el sistema
/// agradece automaticamente al completar el pago.
class AudioService {
  static DateTime? _lastPlayed;

  // 🔥 UN SOLO PLAYER para toda la app (no se destruye)
  static final AudioPlayer _player = AudioPlayer();
  static bool _isInitialized = false;

  // Flag para identificar llamadas remotas (desde endpoint)
  static bool _isRemoteCall = false;

  /// Cooldown configurable entre reproducciones (por defecto 5 segundos).
  static Duration cooldown = const Duration(seconds: 5);

  /// 🔥 Inicializar el player (sin setPlayerProperties porque no existe)
  static void _init() {
    if (!_isInitialized) {
      // Nota: No hay setPlayerProperties en audioplayers
      // PulseAudio detecta automáticamente el nombre del binario
      _isInitialized = true;
      debugPrint('[AudioService] ✅ Player inicializado (stream permanente)');
    }
  }

  /// Marcar una reproducción como "remota" (desde endpoint)
  static void setRemoteCall(bool isRemote) {
    _isRemoteCall = isRemote;
    if (isRemote) {
      debugPrint('[AudioService] 📡 Modo remoto activado');
    }
  }

  /// Linux: fuerza el volumen del sink default a 130% (+6dB) para compensar
  /// la pérdida de ganancia en el pipeline GStreamer → PulseAudio.
  ///
  /// Cada [play()] crea un nuevo sink input en PulseAudio, por eso se llama
  /// después de cada reproducción y no solo en el init de la app.
  static Future<void> _boostLinuxVolume() async {
    try {
      // Pequeña espera para dar tiempo a GStreamer a registrar el sink input
      await Future.delayed(const Duration(milliseconds: 300));
      await Process.run('pactl', ['set-sink-volume', '@DEFAULT_SINK@', '90%']);
      debugPrint('[AudioService] 🔊 Volumen boosteado a 90%');
    } catch (_) {
      // Fallo silencioso: no interrumpir la reproducción
    }
  }

  /// Reproduce un asset de audio.
  static Future<bool> play(
    String assetPath, {
    bool force = false,
    double volume = 1.0,
    String? displayText,
  }) async {
    // Asegurar que el player esté inicializado
    _init();

    final now = DateTime.now();

    // Cooldown anti-spam
    if (!force &&
        _lastPlayed != null &&
        now.difference(_lastPlayed!) < cooldown) {
      final remaining = cooldown - now.difference(_lastPlayed!);
      debugPrint(
          '[AudioService] Cooldown activo. Faltan ${remaining.inSeconds}s para "$assetPath"');
      return false;
    }
    _lastPlayed = now;

    // Si es llamada remota, forzar volumen al 100%
    if (_isRemoteCall) {
      volume = 1.0; // 100%
      debugPrint(
          '[AudioService] 📢 Reproducción remota: Volumen forzado al 100%');
      _isRemoteCall = false; // Resetear flag después de usar
    }

    try {
      debugPrint('[AudioService] Reproduciendo: $assetPath (volume=$volume)');
      AudioNotificationService.notifyPlaying(assetPath,
          displayText: displayText);

      // Usar el MISMO player, no crear uno nuevo
      await _player.setVolume(volume);
      await _player.play(AssetSource(assetPath));

      // Linux: boostear volumen del sistema inmediatamente después de empezar
      // a reproducir, porque GStreamer crea un nuevo sink input cada vez.
      if (Platform.isLinux) {
        await _boostLinuxVolume();
      }

      await _player.onPlayerComplete.first;

      debugPrint('[AudioService] ✅ Finalizado: $assetPath');
      AudioNotificationService.notifyStopped();
      return true;
    } catch (e, stack) {
      debugPrint('[AudioService] ❌ ERROR reproduciendo "$assetPath": $e');
      debugPrint('[AudioService] StackTrace: $stack');
      AudioNotificationService.notifyStopped();
      return false;
    }
  }

  /// Detiene cualquier audio que este sonando actualmente.
  static Future<void> stop() async {
    debugPrint('[AudioService] Deteniendo reproduccion activa');
    await _player.stop();
    AudioNotificationService.notifyStopped();
  }

  /// Limpiar recursos SOLO cuando la app cierra
  static void dispose() {
    _player.dispose();
    _isInitialized = false;
    debugPrint('[AudioService] 🧹 Recursos liberados');
  }

  // ============================================================
  // Métodos públicos para reproducir audios específicos
  // ============================================================

  /// Reproduce el saludo 'deseas un cafe?'.
  static Future<bool> playQuestion(
          {bool force = false, String? displayText}) async =>
      play('audio/question_coffe.wav',
          force: force, displayText: displayText ?? AudioMessages.question);

  /// Reproduce el agradecimiento post-pago.
  static Future<bool> playThanks(
          {bool force = false, String? displayText}) async =>
      play('audio/thanks_shopping.wav',
          force: force, displayText: displayText ?? AudioMessages.thanks);

  /// Reproduce el audio de invitacion a comprar.
  static Future<bool> playBuy(
          {bool force = false, String? displayText}) async =>
      play('audio/purchase_buy.wav',
          force: force, displayText: displayText ?? AudioMessages.buy);

  /// Reproduce el audio de notificacion de orden recibida.
  static Future<bool> playThereIsAnOrder(
          {bool force = false, String? displayText}) async =>
      play('audio/there_is_an_order.wav',
          force: force,
          displayText: displayText ?? AudioMessages.orderReceived);

  static Future<bool> playAttentionExcuseMe(
          {bool force = false, String? displayText}) async =>
      play('audio/attention_excuse_me.wav',
          force: force, displayText: displayText ?? AudioMessages.attention);

  static Future<bool> playCollectTray(
          {bool force = false, String? displayText}) async =>
      play('audio/collect_tray.wav',
          force: force, displayText: displayText ?? AudioMessages.collectTray);

  /// Reproduce el audio de "aqui esta tu cafe".
  static Future<bool> playHereIsCoffee(
          {bool force = false, String? displayText}) async =>
      play('audio/here_is_coffee.wav',
          force: force, displayText: displayText ?? AudioMessages.coffeeReady);
}
