import 'package:flutter/material.dart';

/// Indicador visual de que el carrusel es deslizable hacia los lados.
///
/// Estilos disponibles:
/// - [SwipeHintStyle.neon]      → círculo con glow rojo pulsante
/// - [SwipeHintStyle.neonWhite] → círculo con glow blanco pulsante
/// - [SwipeHintStyle.glass]     → píldora con efecto vidrio esmerilado
/// - [SwipeHintStyle.accent]    → círculo sólido con color de acento
enum SwipeHintStyle { neon, neonWhite, glass, accent }

/// Par de flechas izquierda/derecha para indicar swipe en el carrusel.
class CarouselSwipeHint extends StatelessWidget {
  final SwipeHintStyle style;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final double iconSize;
  final double hitArea;

  const CarouselSwipeHint({
    super.key,
    this.style = SwipeHintStyle.neon,
    required this.onPrevious,
    required this.onNext,
    this.iconSize = 28,
    this.hitArea = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 0,
          bottom: 0,
          child: Center(
            child: _SwipeArrow(
              direction: AxisDirection.left,
              style: style,
              onTap: onPrevious,
              iconSize: iconSize,
              hitArea: hitArea,
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 0,
          bottom: 0,
          child: Center(
            child: _SwipeArrow(
              direction: AxisDirection.right,
              style: style,
              onTap: onNext,
              iconSize: iconSize,
              hitArea: hitArea,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Flecha individual (privada)
// ---------------------------------------------------------------------------
class _SwipeArrow extends StatefulWidget {
  final AxisDirection direction;
  final SwipeHintStyle style;
  final VoidCallback onTap;
  final double iconSize;
  final double hitArea;

  const _SwipeArrow({
    required this.direction,
    required this.style,
    required this.onTap,
    required this.iconSize,
    required this.hitArea,
  });

  @override
  State<_SwipeArrow> createState() => _SwipeArrowState();
}

class _SwipeArrowState extends State<_SwipeArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    if (widget.style == SwipeHintStyle.neon ||
        widget.style == SwipeHintStyle.neonWhite) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  IconData get _icon => widget.direction == AxisDirection.left
      ? Icons.chevron_left_rounded
      : Icons.chevron_right_rounded;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.hitArea,
        height: widget.hitArea,
        child: Center(
          child: switch (widget.style) {
            SwipeHintStyle.neon => _buildNeon(),
            SwipeHintStyle.neonWhite => _buildNeonWhite(),
            SwipeHintStyle.glass => _buildGlass(),
            SwipeHintStyle.accent => _buildAccent(),
          },
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // ESTILO 1: NEÓN (círculo con glow pulsante)
  // -----------------------------------------------------------------------
  Widget _buildNeon() {
    return AnimatedBuilder(
      listenable: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF6B6B).withOpacity(0.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _icon,
              color: const Color(0xFFFF6B6B),
              size: widget.iconSize,
            ),
          ),
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // ESTILO 2: NEÓN BLANCO (círculo con glow blanco pulsante)
  // -----------------------------------------------------------------------
  Widget _buildNeonWhite() {
    return AnimatedBuilder(
      listenable: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.35),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _icon,
              color: Colors.white.withOpacity(0.85),
              size: widget.iconSize,
            ),
          ),
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // ESTILO 3: GLASS (píldora con efecto vidrio esmerilado)
  // -----------------------------------------------------------------------
  Widget _buildGlass() {
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.18),
            Colors.white.withOpacity(0.06),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _icon,
        color: Colors.white.withOpacity(0.85),
        size: widget.iconSize + 4,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // ESTILO 3: ACCENT (círculo sólido con color de acento)
  // -----------------------------------------------------------------------
  Widget _buildAccent() {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFF6B6B),
        boxShadow: [
          BoxShadow(
            color: Color(0x40FF6B6B),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _icon,
        color: Colors.white,
        size: widget.iconSize,
      ),
    );
  }
}

/// Widget auxiliar para animaciones que no requieren escuchar al controller.
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => builder(context, null);
}
