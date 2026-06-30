import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/ui/themes/app_colors.dart';

/// Posición del overlay en la pantalla.
enum AudioOverlayPosition {
  top,
  bottom,
}

/// Widget overlay llamativo que muestra texto cuando se reproduce audio.
/// Se oculta automáticamente cuando se cambia de vista o se cancela el pago.
class AudioOverlayWidget extends StatefulWidget {
  final String text;
  final bool isVisible;
  final VoidCallback? onDismiss;
  final Duration autoHideDuration;
  final IconData icon;
  final AudioOverlayPosition position;

  const AudioOverlayWidget({
    super.key,
    required this.text,
    required this.isVisible,
    this.onDismiss,
    this.autoHideDuration = const Duration(seconds: 10),
    this.icon = Icons.volume_up,
    this.position = AudioOverlayPosition.bottom,
  });

  @override
  State<AudioOverlayWidget> createState() => _AudioOverlayWidgetState();
}

class _AudioOverlayWidgetState extends State<AudioOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    if (widget.isVisible) {
      _show();
    }
  }

  @override
  void didUpdateWidget(AudioOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _show();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _hide();
    }
  }

  void _show() {
    _controller.forward();
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(widget.autoHideDuration, () {
      if (mounted) {
        _hide();
        widget.onDismiss?.call();
      }
    });
  }

  void _hide() {
    _controller.reverse();
    _autoHideTimer?.cancel();
  }

  @override
  void dispose() {
    _controller.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.9),
              AppColors.accent.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 3,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                color: AppColors.background,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Reproduciendo audio',
                    style: TextStyle(
                      color: AppColors.background.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.background,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Indicador de ondas de sonido animadas
            _buildSoundWaves(),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundWaves() {
    return SizedBox(
      width: 30,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (index) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 300 + (index * 100)),
            curve: Curves.easeInOut,
            width: 4,
            height: _controller.isAnimating
                ? (8 + (index * 4)).toDouble()
                : 4,
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

/// Manager para controlar el AudioOverlay globalmente.
class AudioOverlayManager {
  static OverlayEntry? _currentOverlay;
  static bool _isVisible = false;

  /// Muestra el overlay con el texto especificado.
  static void show(
    BuildContext context,
    String text, {
    IconData icon = Icons.volume_up,
    AudioOverlayPosition position = AudioOverlayPosition.bottom,
  }) {
    hide(); // Ocultar overlay anterior si existe

    _isVisible = true;
    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: position == AudioOverlayPosition.top
            ? MediaQuery.of(context).padding.top + 16
            : null,
        bottom: position == AudioOverlayPosition.bottom
            ? 120
            : null,
        left: 0,
        right: 0,
        child: AudioOverlayWidget(
          text: text,
          isVisible: _isVisible,
          icon: icon,
          position: position,
          onDismiss: () {
            hide();
          },
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  /// Oculta el overlay actual.
  static void hide() {
    if (_currentOverlay != null) {
      _isVisible = false;
      _currentOverlay!.remove();
      _currentOverlay = null;
    }
  }

  /// Verifica si el overlay está visible.
  static bool get isVisible => _isVisible;
}