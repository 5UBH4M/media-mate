import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppTheme {
  static const double borderRadiusValue = 16.0;
  static final BorderRadius borderRadius = BorderRadius.circular(borderRadiusValue);

  // Modern Dark Theme Palette (Default)
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      surface: const Color(0xFF12141C),
      primary: const Color(0xFF8F93FF),
      onPrimary: const Color(0xFF000666),
      primaryContainer: const Color(0xFF262C7F),
      onPrimaryContainer: const Color(0xFFE0E0FF),
      secondary: const Color(0xFF00E5FF),
      onSecondary: const Color(0xFF00363D),
      secondaryContainer: const Color(0xFF004F59),
      onSecondaryContainer: const Color(0xFFB2F5FF),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      outline: const Color(0xFF90909A),
      shadow: const Color(0xFF000000),
    ),
    scaffoldBackgroundColor: const Color(0xFF0B0C10),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF12141C),
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: const Color(0xFF8F93FF),
      foregroundColor: const Color(0xFF000666),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Color(0xFF8F93FF),
      inactiveTrackColor: Color(0xFF2E334D),
      thumbColor: Color(0xFF8F93FF),
      valueIndicatorColor: Color(0xFF12141C),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1C1F2E),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      elevation: 2,
    ),
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      titleLarge: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
      titleMedium: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
      bodyLarge: const TextStyle(fontSize: 16, color: Color(0xFFE2E2E9)),
      bodyMedium: const TextStyle(fontSize: 14, color: Color(0xFFC5C5D3)),
    ),
  );

  // Modern Light Theme Palette
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      surface: const Color(0xFFF8F9FE),
      primary: const Color(0xFF4C53E6),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE0E0FF),
      onPrimaryContainer: const Color(0xFF000666),
      secondary: const Color(0xFF006874),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFB2F5FF),
      onSecondaryContainer: const Color(0xFF001F24),
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      outline: const Color(0xFF767680),
      shadow: const Color(0xFF000000),
    ),
    scaffoldBackgroundColor: const Color(0xFFF1F3FB),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Color(0xFF1B1B1F)),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1B1B1F),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: const Color(0xFF4C53E6),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Color(0xFF4C53E6),
      inactiveTrackColor: Color(0xFFE1E2EC),
      thumbColor: Color(0xFF4C53E6),
      valueIndicatorColor: Color(0xFFF8F9FE),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      elevation: 1,
    ),
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
      titleLarge: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22, color: Color(0xFF1B1B1F)),
      titleMedium: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Color(0xFF1B1B1F)),
      bodyLarge: const TextStyle(fontSize: 16, color: Color(0xFF1B1B1F)),
      bodyMedium: const TextStyle(fontSize: 14, color: Color(0xFF46464F)),
    ),
  );
}

// Provider for dark/light mode setting
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark; // Dark mode as default

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
  
  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}
