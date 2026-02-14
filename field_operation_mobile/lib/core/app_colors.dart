import 'package:flutter/material.dart';

class AppColors {
  // Palette Hijau (Dari Terang ke Gelap)
  static const Color surface = Color(0xFFF0FDF4); // Background (50)
  static const Color card = Color(0xFFDCFCE7);    // Card BG (100)
  static const Color accentLight = Color(0xFFBBF7D0); // (200)
  static const Color primaryLight = Color(0xFF4ADE80); // (400)
  static const Color primary = Color(0xFF15803D); // MAIN COLOR (700)
  static const Color textDark = Color(0xFF14532D); // Text (900)
  static const Color amber = Color(0xFFD97706);   // Warna Status/Warning

  // Material Swatch untuk Theme
  static const MaterialColor primaryMaterial = MaterialColor(0xFF15803D, {
    50: surface,
    100: card,
    200: accentLight,
    300: Color(0xFF86EFAC),
    400: primaryLight,
    500: Color(0xFF22C55E),
    600: Color(0xFF16A34A),
    700: primary,
    800: Color(0xFF166534),
    900: textDark,
  });
}