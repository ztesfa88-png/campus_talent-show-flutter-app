import 'package:flutter/material.dart';

/// Central design token file — single source of truth for all colors.
class AppColors {
  // Brand
  static const primary   = Color(0xFF6366F1); // Indigo
  static const secondary = Color(0xFF8B5CF6); // Violet
  static const accent    = Color(0xFF22C55E); // Green

  // Backgrounds
  static const background = Color(0xFFF8FAFC);
  static const surface    = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF1F5F9); // subtle card bg

  // Text
  static const textMain = Color(0xFF0F172A);
  static const textSub  = Color(0xFF64748B);
  static const textHint = Color(0xFF94A3B8);

  // Status
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error   = Color(0xFFEF4444);
  static const info    = Color(0xFF3B82F6);

  // Borders
  static const border     = Color(0xFFE2E8F0);
  static const borderFocus = primary;

  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const accentGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> primaryShadow = [
    BoxShadow(color: primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
  ];
  static List<BoxShadow> accentShadow = [
    BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
  ];
}
