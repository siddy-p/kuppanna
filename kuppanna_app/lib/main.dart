import 'package:flutter/material.dart';
import 'screens/checkout_screen.dart';

void main() {
  runApp(const KuppannaApp());
}

class KuppannaApp extends StatelessWidget {
  const KuppannaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Kuppanna's — Food Delivery",
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const CheckoutScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE65100),   // deep orange — Kuppanna brand
      brightness: brightness,
      primary:     const Color(0xFFE65100),
      secondary:   const Color(0xFF00897B),
      tertiary:    const Color(0xFFF4511E),
      surface:     isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
    );

    return ThemeData(
      useMaterial3:    true,
      colorScheme:     colorScheme,
      fontFamily:      'Inter',
      scaffoldBackgroundColor: colorScheme.surface,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation:       0,
        centerTitle:     true,
        titleTextStyle:  const TextStyle(
          color:      Colors.white,
          fontSize:   18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled:          true,
        fillColor:       isDark
            ? const Color(0xFF1E1E1E)
            : colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   BorderSide(color: colorScheme.primary, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          elevation:       0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 50),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side:            BorderSide(color: colorScheme.primary),
          shape:           RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          minimumSize:     const Size(double.infinity, 50),
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color:     isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}
