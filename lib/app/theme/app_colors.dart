import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary - Purple
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFF9F67F5);
  static const Color primaryDark = Color(0xFF5B21B6);

  // Accent - Pink
  static const Color accent = Color(0xFFEC4899);
  static const Color accentLight = Color(0xFFF472B6);

  // Google-inspired accent palette
  static const Color blue    = Color(0xFF4285F4);
  static const Color red     = Color(0xFFEA4335);
  static const Color yellow  = Color(0xFFFBBC05);
  static const Color green   = Color(0xFF34A853);
  static const Color cyan    = Color(0xFF4FC3F7);
  static const Color orange  = Color(0xFFF9AB00);

  // Gold
  static const Color gold      = Color(0xFFFFD700);
  static const Color goldLight = Color(0xFFFFE55C);

  // Light background system
  static const Color background  = Color(0xFFFFFFFF);
  static const Color surface     = Color(0xFFF8F9FE);
  static const Color surfaceLight = Color(0xFFF0F2FF);
  static const Color card        = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint      = Color(0xFF94A3B8);

  // Status
  static const Color online  = Color(0xFF22C55E);
  static const Color offline = Color(0xFF94A3B8);
  static const Color error   = Color(0xFFEA4335);
  static const Color warning = Color(0xFFF9AB00);
  static const Color success = Color(0xFF34A853);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroBannerGradient = LinearGradient(
    colors: [Color(0xFFE8E0FF), Color(0xFFF6D8FF), Color(0xFFFFF0C7), Color(0xFFFFE4E8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Room seat colors (kept for room screen)
  static const Color seatEmpty    = Color(0xFFF0F2FF);
  static const Color seatOccupied = Color(0xFFEDE9FF);
  static const Color seatHost     = Color(0xFFDDD6FE);
  static const Color seatLocked   = Color(0xFFE5E7EB);
  static const Color seatMuted    = Color(0xFFFFE4E6);

  // Divider
  static const Color divider = Color(0xFFE8ECF4);

  // Card shadow
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF3C4043).withAlpha(26),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get fabShadow => [
    BoxShadow(
      color: primary.withAlpha(80),
      blurRadius: 24,
      spreadRadius: 2,
      offset: const Offset(0, 8),
    ),
  ];
}
