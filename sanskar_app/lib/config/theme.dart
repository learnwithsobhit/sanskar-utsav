import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sacred saffron & gold design system for Sanskar Utsav.
class SanskarTheme {
  // ─── Sacred Color Palette ───
  static const Color saffron = Color(0xFFFF6F00);
  static const Color deepSaffron = Color(0xFFE65100);
  static const Color gold = Color(0xFFFFD700);
  static const Color lightGold = Color(0xFFFFF0B3);
  static const Color warmCream = Color(0xFFFFF8E7);
  static const Color vermillion = Color(0xFFE23D28);
  static const Color turmeric = Color(0xFFF4C430);
  static const Color sacred = Color(0xFFB71C1C); // deep red
  static const Color maroon = Color(0xFF2D0A0A);
  static const Color darkCharcoal = Color(0xFF1A1A2E);
  static const Color softWhite = Color(0xFFFFFDF7);
  static const Color peach = Color(0xFFFFE0B2);
  static const Color lotusGreen = Color(0xFF2E7D32);

  // Category colors
  static const Color ritualColor = Color(0xFFFF6F00);
  static const Color feastColor = Color(0xFF4CAF50);
  static const Color celebrationColor = Color(0xFF9C27B0);

  // ─── Gradients ───
  static const LinearGradient saffronGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
  );

  static const LinearGradient sacredGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF6F00), Color(0xFFB71C1C)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1A2E), Color(0xFF2D0A0A)],
  );

  // ─── Shadows ───
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: saffron.withAlpha(30),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withAlpha(25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ─── Border Radius ───
  static BorderRadius get radiusSm => BorderRadius.circular(8);
  static BorderRadius get radiusMd => BorderRadius.circular(12);
  static BorderRadius get radiusLg => BorderRadius.circular(16);
  static BorderRadius get radiusXl => BorderRadius.circular(24);

  // ─── Category Color ───
  static Color categoryColor(String category) {
    switch (category) {
      case 'ritual':
        return ritualColor;
      case 'feast':
        return feastColor;
      case 'celebration':
        return celebrationColor;
      default:
        return saffron;
    }
  }

  // ─── Theme Data ───
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: warmCream,
      primaryColor: saffron,
      colorScheme: ColorScheme.fromSeed(
        seedColor: saffron,
        brightness: Brightness.light,
        primary: saffron,
        secondary: gold,
        surface: softWhite,
        error: vermillion,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: darkCharcoal,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: darkCharcoal,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkCharcoal,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkCharcoal,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: darkCharcoal,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          color: darkCharcoal.withAlpha(200),
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          color: darkCharcoal.withAlpha(180),
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          color: darkCharcoal.withAlpha(150),
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: darkCharcoal,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkCharcoal,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: softWhite,
        shape: RoundedRectangleBorder(
          borderRadius: radiusMd,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: saffron,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: radiusMd,
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: saffron.withAlpha(50)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: saffron.withAlpha(50)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(color: saffron, width: 2),
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: darkCharcoal.withAlpha(100),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: softWhite,
        selectedItemColor: saffron,
        unselectedItemColor: darkCharcoal.withAlpha(120),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: saffron,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      dividerTheme: DividerThemeData(
        color: saffron.withAlpha(20),
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: peach.withAlpha(100),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: deepSaffron,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: radiusSm,
        ),
      ),
    );
  }
}
