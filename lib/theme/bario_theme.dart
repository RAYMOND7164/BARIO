import 'package:flutter/material.dart';

/// Couleurs de Bario : bleu nuit, turquoise et corail.
/// Un seul mode, sombre : lisible dans la pénombre du bar.
class BC {
  static const fond = Color(0xFF0A0E1A);
  static const surface = Color(0xFF121828);
  static const surface2 = Color(0xFF1A2236);
  static const bordure = Color(0xFF28324A);

  /// Couleur principale (turquoise).
  static const accent = Color(0xFF1FD1B9);
  static const accentClair = Color(0xFF6EF0DC);
  static const accentFonce = Color(0xFF0E8A7A);
  static const surAccent = Color(0xFF04211D);

  /// Violet du dégradé de la marque.
  static const violet = Color(0xFF7C5CFF);

  /// Couleur secondaire (corail), utilisée dans le logo.
  static const corail = Color(0xFFFF7A59);

  static const texte = Color(0xFFEAF0FA);
  static const gris = Color(0xFF8E9AB5);
  static const vert = Color(0xFF4ADE80);
  static const rouge = Color(0xFFF4607A);
  static const bleu = Color(0xFF8AA6FF);

  static const fondVert = Color(0xFF11291C);
  static const fondRouge = Color(0xFF33141D);
  static const fondAccent = Color(0xFF0D2E2C);
  static const fondBleu = Color(0xFF161E3D);

  /// Dégradé de la marque (logo, en-têtes).
  static const degrade = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, violet, corail],
  );
}

class BarioTheme {
  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: BC.accent,
        onPrimary: BC.surAccent,
        secondary: BC.corail,
        onSecondary: Color(0xFF2A0E05),
        surface: BC.surface,
        onSurface: BC.texte,
        surfaceContainerHighest: BC.surface2,
        error: BC.rouge,
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: BC.fond,
      canvasColor: BC.surface,
      dividerColor: BC.bordure,
    );
    final carte = BorderRadius.circular(20);
    final champ = BorderRadius.circular(14);
    const pilule = StadiumBorder();
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: BC.fond,
        foregroundColor: BC.texte,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: BC.texte),
      ),
      cardTheme: CardThemeData(
        color: BC.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: carte, side: const BorderSide(color: BC.bordure, width: 0.8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BC.surface2,
        border: OutlineInputBorder(borderRadius: champ, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: champ, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: champ, borderSide: const BorderSide(color: BC.accent, width: 2)),
        labelStyle: const TextStyle(color: BC.gris),
        prefixIconColor: BC.accent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BC.accent,
          foregroundColor: BC.surAccent,
          minimumSize: const Size(64, 50),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2),
          shape: pilule,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BC.accent,
          minimumSize: const Size(64, 50),
          side: const BorderSide(color: BC.accentFonce, width: 1.2),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: pilule,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: BC.accent, shape: pilule)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BC.corail,
        foregroundColor: Color(0xFF2A0E05),
        shape: StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BC.surface2,
        contentTextStyle: const TextStyle(color: BC.texte, fontSize: 15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: champ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: BC.surface,
        indicatorColor: BC.fondAccent,
        indicatorShape: StadiumBorder(),
        selectedIconTheme: IconThemeData(color: BC.accent),
        unselectedIconTheme: IconThemeData(color: BC.gris),
        selectedLabelTextStyle: TextStyle(color: BC.accent, fontWeight: FontWeight.w800),
        unselectedLabelTextStyle: TextStyle(color: BC.gris),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: champ),
        selectedTileColor: BC.fondAccent,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: BC.surface2,
        selectedColor: BC.fondAccent,
        side: BorderSide.none,
        shape: pilule,
        labelStyle: const TextStyle(color: BC.texte),
      ),
    );
  }
}
