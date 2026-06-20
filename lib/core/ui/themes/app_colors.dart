import 'package:flutter/material.dart';

/// Paleta de colores centralizada (estilo KioskoBot).
abstract final class AppColors {
  static const background  = Color(0xFF050505);
  static const surface     = Color(0xFF1A1A1A);
  static const surfaceAlt  = Color(0xFF2A2A2A);
  static const surfaceDark = Color(0xFF111111);

  static const border      = Color(0xFF333333);
  static const borderMuted = Color(0xFF555555);
  static const borderLight = Color(0xFF888888);

  static const textPrimary   = Colors.white;
  static const textLabel     = Color(0xFFCCCCCC);
  static const textSecondary = Color(0x8AFFFFFF);
  static const textCaption   = Color(0xFF888888);
  static const textMuted     = Color(0x61FFFFFF);
  static const textDisabled  = Color(0x3DFFFFFF);

  static const accent       = Color(0xFFFFFFFF);
  static const accentSubtle = Color(0x1FFFFFFF);
  static const accentGlow   = Color(0x33FFFFFF);

  static const error   = Color(0xFFFF4444);
  static const warning = Color(0xFFFF9800);
}
