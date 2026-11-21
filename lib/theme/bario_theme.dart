import 'package:flutter/material.dart';

/// Couleurs de Bario : encre de nuit + un seul accent lilas.
/// Un seul mode, sombre : reposant pour les yeux dans la pénombre,
/// contrasté pour lire vite. Les couleurs vives sont réservées aux états
/// (payé, refusé, alerte), jamais à la décoration.
class HC {
  static const fond = Color(0xFF0B0C10);
  static const surface = Color(0xFF13151B);
  static const surface2 = Color(0xFF1B1E26);
  static const bordure = Color(0xFF2A2E38);
  static const accent = Color(0xFFA594F9);
  static const accentClair = Color(0xFFC9BEFF);
  static const accentFonce = Color(0xFF7A6CD0);
  static const surAccent = Color(0xFF130E2E);
  static const texte = Color(0xFFECEDF2);
  static const gris = Color(0xFF8D91A1);
  static const vert = Color(0xFF4CC38A);
  static const rouge = Color(0xFFEF6B6B);
  static const bleu = Color(0xFF7FA6D9);

  static const fondVert = Color(0xFF13261D);
  static const fondRouge = Color(0xFF2E1719);
  static const fondAccent = Color(0xFF1F1B3A);
  static const fondBleu = Color(0xFF141E30);
}

class BarioTheme {
  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: HC.accent,
        onPrimary: HC.surAccent,
        secondary: HC.accentClair,
        onSecondary: HC.surAccent,
        surface: HC.surface,
        onSurface: HC.texte,
        surfaceContainerHighest: HC.surface2,
        error: HC.rouge,
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: HC.fond,
      canvasColor: HC.surface,
      dividerColor: HC.bordure,
    );
    final arrondi = BorderRadius.circular(14);
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: HC.fond,
        foregroundColor: HC.texte,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: HC.texte),
      ),
      cardTheme: CardThemeData(
        color: HC.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: arrondi, side: const BorderSide(color: HC.bordure)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HC.surface2,
        border: OutlineInputBorder(borderRadius: arrondi, borderSide: const BorderSide(color: HC.bordure)),
        enabledBorder: OutlineInputBorder(borderRadius: arrondi, borderSide: const BorderSide(color: HC.bordure)),
        focusedBorder: OutlineInputBorder(borderRadius: arrondi, borderSide: const BorderSide(color: HC.accent, width: 2)),
        labelStyle: const TextStyle(color: HC.gris),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HC.accent,
          foregroundColor: HC.surAccent,
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: arrondi),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HC.accent,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: HC.bordure),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: arrondi),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: HC.accent)),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: HC.surface2,
        contentTextStyle: TextStyle(color: HC.texte, fontSize: 15),
        behavior: SnackBarBehavior.floating,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: HC.surface,
        indicatorColor: HC.fondAccent,
        selectedIconTheme: IconThemeData(color: HC.accent),
        unselectedIconTheme: IconThemeData(color: HC.gris),
        selectedLabelTextStyle: TextStyle(color: HC.accent, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: HC.gris),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: HC.surface2,
        selectedColor: HC.fondAccent,
        side: const BorderSide(color: HC.bordure),
        labelStyle: const TextStyle(color: HC.texte),
      ),
    );
  }
}
