import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Widget que renderiza un codigo QR desde base64, URL o muestra loading.
///
/// Soporta 3 modos:
/// - [qrBase64] es null/empty -> muestra CircularProgressIndicator + texto opcional
/// - [qrBase64] empieza con 'http' -> carga desde red (Image.network)
/// - [qrBase64] es base64 plano o data URI -> decodifica y renderiza (Image.memory)
class QrDisplayWidget extends StatelessWidget {
  final String? qrBase64;
  final double size;
  final String loadingText;
  final String fallbackText;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final List<BoxShadow>? boxShadow;

  const QrDisplayWidget({
    super.key,
    this.qrBase64,
    this.size = 280,
    this.loadingText = 'Generando QR...',
    this.fallbackText = 'QR no disponible',
    this.backgroundColor = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (qrBase64 == null || qrBase64!.isEmpty) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(loadingText, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
    } else if (qrBase64!.trim().startsWith('http')) {
      content = Image.network(
        qrBase64!,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('QrDisplayWidget: error cargando imagen: $error');
          return _fallback(context);
        },
      );
    } else {
      final bytes = _decodeBase64(qrBase64!);
      if (bytes != null) {
        content = Image.memory(bytes, fit: BoxFit.contain);
      } else {
        content = _fallback(context);
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }

  Widget _fallback(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.grey),
        const SizedBox(height: 8),
        Text(fallbackText, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Uint8List? _decodeBase64(String input) {
    try {
      String clean = input.trim();
      // Soporta data URI: data:image/png;base64,...
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }
}
