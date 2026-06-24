import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Reproductor de video en loop para la pantalla de atraccion.
///
/// Usa [media_kit] que soporta Windows, Linux, macOS, Android, iOS y web.
/// Espera un asset local en [assetPath], por defecto `assets/videos/attract.mp4`.
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

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    debugPrint('[AttractVideoPlayer] Iniciando carga de video: ${widget.assetPath}');
    try {
      final player = Player();
      final controller = VideoController(player);

      debugPrint('[AttractVideoPlayer] Player creado, abriendo asset...');
      await player.open(Media('asset://${widget.assetPath}'));
      debugPrint('[AttractVideoPlayer] Asset abierto OK');

      await player.setVolume(0); // Mute para no competir con el audio de saludo
      await player.setPlaylistMode(PlaylistMode.loop);
      debugPrint('[AttractVideoPlayer] Configurado: mute=true, loop=true');

      if (mounted) {
        setState(() {
          _player = player;
          _controller = controller;
          _isReady = true;
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
        });
      }
    }
  }

  @override
  void dispose() {
    debugPrint('[AttractVideoPlayer] dispose() - liberando player');
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SizedBox.expand(
      child: Video(
        controller: _controller!,
        fit: BoxFit.cover,
        controls: null, // Sin controles de pausa/play
      ),
    );
  }
}
