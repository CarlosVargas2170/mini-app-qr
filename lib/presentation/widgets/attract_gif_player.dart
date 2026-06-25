import 'package:flutter/material.dart';

/// Reproductor de GIF animado para la pantalla de atraccion.
///
/// Usa [Image.asset] nativo de Flutter que soporta GIF animados
/// sin necesidad de plugins de video ni OpenGL.
///
/// Espera un asset local en [assetPath], por defecto `assets/images/attract.gif`.
class AttractGifPlayer extends StatelessWidget {
  final String assetPath;

  const AttractGifPlayer({
    super.key,
    this.assetPath = 'assets/images/attract.gif',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        assetPath,
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
                  Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
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
    );
  }
}
