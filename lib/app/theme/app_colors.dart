import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary - Deep Purple Party Theme
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFF9F67F5);
  static const Color primaryDark = Color(0xFF5B21B6);

  // Accent - Neon Pink
  static const Color accent = Color(0xFFEC4899);
  static const Color accentLight = Color(0xFFF472B6);

  // Gold - VIP & Gifts
  static const Color gold = Color(0xFFFFD700);
  static const Color goldLight = Color(0xFFFFE55C);

  // Background
  static const Color background = Color(0xFF0F0F1A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF252540);
  static const Color card = Color(0xFF1E1E35);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0C8);
  static const Color textHint = Color(0xFF6B6B8A);

  // Status
  static const Color online = Color(0xFF22C55E);
  static const Color offline = Color(0xFF6B7280);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
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

  // Room seat colors
  static const Color seatEmpty = Color(0xFF252540);
  static const Color seatOccupied = Color(0xFF2D1B5E);
  static const Color seatHost = Color(0xFF4C1D95);
  static const Color seatLocked = Color(0xFF374151);
  static const Color seatMuted = Color(0xFF7F1D1D);

  // Divider
  static const Color divider = Color(0xFF2A2A45);
}
