import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Reproductor de video en loop para la pantalla de atraccion.
///
/// Usa [media_kit] que soporta Windows, Linux, macOS, Android, iOS y web.
/// Espera un asset local en [assetPath], por defecto `assets/videos/attract.mp4`.
///
/// En Linux (especialmente ARM/Jetson) puede mostrar pantalla azul con H/W rendering.
/// Este widget incluye workarounds: fondo oscuro, retry, y logs detallados.
class AttractVideoPlayer extends StatefulWidget {
  final String assetPath;

  const AttractVideoPlayer({
    super.key,
    this.assetPath = 'assets/videos/attract.mp4',
  });

  @override
  State<AttractVideoPlayer> createState() => _AttractVideoPlayerState();
}

class _AttractVideoPlayerState extends State<AttractVideoPlayer> {
  Player? _player;
  VideoController? _controller;
  bool _isReady = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    debugPrint('[AttractVideoPlayer] Iniciando carga de video: ${widget.assetPath}');
    try {
      // En Linux ARM (Jetson), el H/W rendering a veces muestra pantalla azul.
      // Creamos el player y esperamos un momento para que el texture se inicialice.
      final player = Player();
      final controller = VideoController(player);

      debugPrint('[AttractVideoPlayer] Player creado, abriendo asset...');
      await player.open(Media('asset://${widget.assetPath}'));
      debugPrint('[AttractVideoPlayer] Asset abierto OK');

      await player.setVolume(0); // Mute para no competir con el audio de saludo
      await player.setPlaylistMode(PlaylistMode.loop);
      debugPrint('[AttractVideoPlayer] Configurado: mute=true, loop=true');

      // Pequeno delay para que el texture se inicialice antes de mostrar
      // (evita pantalla azul/blanca en Linux con H/W rendering)
      if (Platform.isLinux) {
        debugPrint('[AttractVideoPlayer] Linux detectado, esperando 300ms para texture...');
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (mounted) {
        setState(() {
          _player = player;
          _controller = controller;
          _isReady = true;
          _hasError = false;
        });
        debugPrint('[AttractVideoPlayer] Widget actualizado (isReady=true)');
      } else {
        debugPrint('[AttractVideoPlayer] Widget ya no esta montado, liberando player');
        player.dispose();
      }
    } catch (e, stack) {
      debugPrint('[AttractVideoPlayer] ERROR al cargar/reproducir video: $e');
      debugPrint('[AttractVideoPlayer] StackTrace: $stack');
      if (mounted) {
        setState(() {
          _isReady = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _retry() async {
    debugPrint('[AttractVideoPlayer] Reintentando carga...');
    setState(() {
      _isReady = false;
      _hasError = false;
    });
    await _player?.dispose();
    _player = null;
    _controller = null;
    await _initVideo();
  }

  @override
  void dispose() {
    debugPrint('[AttractVideoPlayer] dispose() - liberando player');
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fondo oscuro SIEMPRE para evitar parpadeo azul/blanco
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video (o placeholder)
          _buildContent(),

          // Overlay de error con boton retry
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudo cargar el video',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (!_isReady || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    // En Linux (especialmente Jetson ARM), media_kit a veces renderiza
    // un color solido (azul/verde) en vez del video con H/W acceleration.
    // Ponemos un Container negro detras como fallback visual.
    return SizedBox.expand(
      child: ColoredBox(
        color: Colors.black,
        child: Video(
          controller: _controller!,
          fit: BoxFit.cover,
          controls: null, // Sin controles de pausa/play
        ),
      ),
    );
  }
}
