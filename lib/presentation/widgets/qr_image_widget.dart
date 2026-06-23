import 'dart:convert';
import 'package:flutter/material.dart';

/// Widget que renderiza una imagen QR desde base64, URL o muestra un fallback.
class QrImageWidget extends StatelessWidget {
  final String? qrBase64;
  const QrImageWidget({super.key, this.qrBase64});

  @override
  Widget build(BuildContext context) {
    if (qrBase64 == null || qrBase64!.isEmpty) {
      return const _Loading();
    }

    if (qrBase64!.startsWith('http')) {
      return Image.network(
        qrBase64!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const _Loading();
        },
        errorBuilder: (context, error, stackTrace) => const _Fallback(),
      );
    }

    try {
      final raw = qrBase64!.contains(',') ? qrBase64!.split(',').last : qrBase64!;
      final bytes = base64Decode(raw);
      return Image.memory(bytes, fit: BoxFit.contain);
    } catch (_) {
      return const _Fallback();
    }
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.black45, strokeWidth: 3),
          SizedBox(height: 16),
          Text(
            'Generando QR...',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_rounded, color: Colors.black54, size: 80),
          SizedBox(height: 8),
          Text(
            'QR no disponible',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
