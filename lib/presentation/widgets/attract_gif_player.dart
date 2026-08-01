import 'package:flutter/material.dart';

/// Reproductor de GIF animado para la pantalla de atraccion.
///
/// Usa [Image.asset] nativo de Flutter que soporta GIF animados
/// sin necesidad de plugins de video ni OpenGL.
///
/// Cuando cambia el [assetPath], ejecuta una transicion suave con fade:
/// 1. Fade out del GIF actual (250ms)
/// 2. Cambia al nuevo GIF
/// 3. Fade in del nuevo GIF (250ms)
///
/// Esto evita el corte visual brusco al cambiar entre GIFs.
class AttractGifPlayer extends StatefulWidget {
  final String assetPath;

  const AttractGifPlayer({
    super.key,
    // this.assetPath = 'assets/images/attract.gif',
    this.assetPath = 'assets/images/normal.gif',
  });

  @override
  State<AttractGifPlayer> createState() => _AttractGifPlayerState();
}

class _AttractGifPlayerState extends State<AttractGifPlayer>
    with SingleTickerProviderStateMixin {
  /// GIF que se muestra actualmente.
  late String _currentAsset;

  /// Controlador de animacion para el fade.
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  /// Token de cancelacion: si cambia durante una transicion, se aborta.
  int _transitionToken = 0;

  /// Duracion del fade (ida y vuelta).
  static const Duration _fadeDuration = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _currentAsset = widget.assetPath;

    _fadeController = AnimationController(
      vsync: this,
      duration: _fadeDuration,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );

    // Iniciar completamente visible.
    _fadeController.value = 0.0;
  }

  @override
  void didUpdateWidget(AttractGifPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assetPath != oldWidget.assetPath) {
      _performFadeTransition(widget.assetPath);
    }
  }

  /// Ejecuta la transicion con fade para cambiar al [newAsset].
  ///
  /// Si se llama nuevamente antes de terminar, la transicion anterior se
  /// cancela y empieza la nueva (gracias al [_transitionToken]).
  Future<void> _performFadeTransition(String newAsset) async {
    final token = ++_transitionToken;

    // 1. Fade out del GIF actual
    if (!mounted || token != _transitionToken) return;
    await _fadeController.animateTo(1.0);

    // 2. Cambiar al nuevo GIF (con opacidad 0)
    if (!mounted || token != _transitionToken) return;
    setState(() => _currentAsset = newAsset);

    // 3. Fade in del nuevo GIF
    if (!mounted || token != _transitionToken) return;
    await _fadeController.animateTo(0.0);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Image.asset(
          _currentAsset,
          fit: BoxFit.cover,
          gaplessPlayback: true, // Evita parpadeo entre loops
          errorBuilder: (context, error, stackTrace) {
            debugPrint('[AttractGifPlayer] Error cargando GIF: $error');
            return Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported,
                        color: Colors.white54, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'GIF no encontrado',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
