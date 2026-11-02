import 'package:flutter/material.dart';

/// Palette taken from the Sabtawya emblem: Coptic navy lettering on white with
/// the olive Arabic script.
class AppColors {
  const AppColors._();

  static const Color navy = Color(0xFF1B3A6B);
  static const Color navyDark = Color(0xFF12284A);
  static const Color navyLight = Color(0xFF3D63A0);
  static const Color olive = Color(0xFF8A9A2B);
  static const Color oliveLight = Color(0xFFB4C455);

  /// The deep red of the church's golden jubilee emblem.
  static const Color maroon = Color(0xFF8C1C2B);

  /// Warm accents that sit beside the brand colours.
  static const Color gold = Color(0xFFE8A93B);
  static const Color coral = Color(0xFFE76F51);
  static const Color sky = Color(0xFF4FA3D1);

  /// Soft backgrounds for icon badges and tinted panels.
  static const Color navyTint = Color(0xFFE8EEF8);
  static const Color oliveTint = Color(0xFFF1F4DC);
  static const Color goldTint = Color(0xFFFDF3DE);
  static const Color coralTint = Color(0xFFFCE9E3);
  static const Color skyTint = Color(0xFFE3F1F9);

  static const Color surface = Color(0xFFF7F7FB);
  static const Color card = Colors.white;
  static const Color success = Color(0xFF2E7D4F);
  static const Color warning = Color(0xFFB7791F);
  static const Color danger = Color(0xFFB3261E);
  static const Color muted = Color(0xFF6B7280);
}

/// Shared gradients used across the app.
class AppGradients {
  const AppGradients._();

  static const LinearGradient navyHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.navyDark, AppColors.navyLight],
  );

  static const LinearGradient oliveAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.olive, AppColors.oliveLight],
  );

  static const LinearGradient goldAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gold, Color(0xFFF2C46D)],
  );

  static const LinearGradient maroonAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.maroon, AppColors.coral],
  );

  static const LinearGradient warmSurface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF8EC), AppColors.surface],
  );

  static const LinearGradient loginBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.42, 1.0],
    colors: [AppColors.navyDark, AppColors.navy, AppColors.surface],
  );
}

class AppTheme {
  const AppTheme._();

  /// Bundled with the app (assets/fonts), so text looks right offline too.
  static const _font = 'Cairo';

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true);
    final cairoText = base.textTheme.apply(fontFamily: _font);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.olive,
      surface: AppColors.card,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surface,
      visualDensity: VisualDensity.standard,
      textTheme: cairoText,
      fontFamily: _font,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontFamily: _font, 
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        shape: const Border(
          bottom: BorderSide(color: Color(0xFF243F73), width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE9EAF0)),
        ),
        shadowColor: AppColors.navy.withValues(alpha: 0.10),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: const TextStyle(color: AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontFamily: _font, 
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.navy),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        backgroundColor: Colors.white,
        selectedColor: AppColors.oliveTint,
        labelStyle: TextStyle(fontFamily: _font, fontSize: 13, color: AppColors.navy),
        iconTheme: const IconThemeData(color: AppColors.navy),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        indicatorColor: AppColors.oliveLight.withValues(alpha: 0.35),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: _font, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EB), space: 1),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
      ),
    );
  }
}
