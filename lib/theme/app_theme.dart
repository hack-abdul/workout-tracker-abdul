import 'package:flutter/material.dart';

class AppTheme {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  static bool get isDark => themeNotifier.value == ThemeMode.dark;

  // Custom design system colors
  static Color get background => isDark ? const Color(0xFF030712) : const Color(0xFFF9FAFB);
  static Color get surface => isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  static Color get border => isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
  static Color get borderLight => isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
  
  // Custom text colors
  static Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A); // Slate-900
  static Color get textSecondary => isDark ? const Color(0xFF9CA3AF) : const Color(0xFF475569); // Slate-600
  static Color get textMuted => isDark ? const Color(0xFF6B7280) : const Color(0xFF94A3B8); // Slate-400

  // Themes for MaterialApp
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      primaryColor: const Color(0xFF2563EB),
      cardColor: const Color(0xFFFFFFFF),
      dividerColor: const Color(0xFFE5E7EB),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2563EB),
        secondary: Color(0xFF7C3AED),
        background: Color(0xFFF9FAFB),
        surface: Color(0xFFFFFFFF),
        error: Colors.redAccent,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF2563EB),
        selectionColor: Color(0xFF93C5FD),
        selectionHandleColor: Color(0xFF2563EB),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF030712),
      primaryColor: const Color(0xFF2563EB),
      cardColor: const Color(0xFF111827),
      dividerColor: const Color(0xFF1F2937),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF2563EB),
        secondary: Color(0xFF7C3AED),
        background: Color(0xFF030712),
        surface: Color(0xFF111827),
        error: Colors.redAccent,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF2563EB),
        selectionColor: Color(0xFF1E3A8A),
        selectionHandleColor: Color(0xFF2563EB),
      ),
    );
  }
}
