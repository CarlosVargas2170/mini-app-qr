import 'package:flutter/material.dart';
import '../../core/services/audio_service.dart';
import '../../core/ui/themes/app_colors.dart';
import 'audio_overlay_wrapper.dart';

/// Ejemplo de cómo usar el AudioOverlayWrapper en una página.
/// Este widget muestra botones para probar diferentes tipos de audio.
class AudioOverlayExample extends StatelessWidget {
  const AudioOverlayExample({super.key});

  @override
  Widget build(BuildContext context) {
    return AudioOverlayWrapper(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Audio Overlay Example'),
          backgroundColor: AppColors.surface,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Prueba el Audio Overlay',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              _buildAudioButton(
                context,
                '¿Deseas un café?',
                () => AudioService.playQuestion(),
              ),
              const SizedBox(height: 16),
              _buildAudioButton(
                context,
                '¡Gracias por tu compra!',
                () => AudioService.playThanks(),
              ),
              const SizedBox(height: 16),
              _buildAudioButton(
                context,
                '¡Invitación a comprar!',
                () => AudioService.playBuy(),
              ),
              const SizedBox(height: 16),
              _buildAudioButton(
                context,
                '¡Orden recibida!',
                () => AudioService.playThereIsAnOrder(),
              ),
              const SizedBox(height: 16),
              _buildAudioButton(
                context,
                '¡Aquí está tu café!',
                () => AudioService.playHereIsCoffee(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioButton(
    BuildContext context,
    String label,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}