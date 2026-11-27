import 'package:flutter/cupertino.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../widgets/responsive.dart';
import '../widgets/soft_transitions.dart';

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

  static const Color successTint = Color(0xFFE3F3EA);
  static const Color dangerTint = Color(0xFFFBE7E5);

  static const Color surface = Color(0xFFF7F7FB);
  static const Color card = Colors.white;
  static const Color success = Color(0xFF2E7D4F);
  static const Color warning = Color(0xFFB7791F);
  static const Color danger = Color(0xFFB3261E);
  static const Color muted = Color(0xFF566070);

  /// The same hues, darkened so TEXT in them is readable: at least 4.5:1 on
  /// white, on the cream background and on their own light tint up to 20%
  /// (WCAG AA).
  /// Gold text was 2:1. Icons, bars and fills keep the brand colours above.
  static const Color goldText = Color(0xFF906211);
  static const Color coralText = Color(0xFFB93919);
  static const Color skyText = Color(0xFF276E95);
  static const Color oliveText = Color(0xFF616C1E);
  static const Color warningText = Color(0xFF8B5C18);

  /// [color] for text: its readable shade when it is one of the light brand
  /// colours, itself otherwise (navy, maroon, success, danger, muted and
  /// anything else already read well).
  static Color readable(Color color) {
    if (color == gold) return goldText;
    if (color == coral) return coralText;
    if (color == sky) return skyText;
    if (color == olive) return oliveText;
    if (color == warning) return warningText;
    return color;
  }
}

/// The soft background that goes with a status colour: the dedicated tints
/// for success and danger, a light wash of the colour for anything else.
Color statusTint(Color color, [double alpha = 0.12]) {
  if (color == AppColors.success) return AppColors.successTint;
  if (color == AppColors.danger) return AppColors.dangerTint;
  return color.withValues(alpha: alpha);
}

/// Direction-aware arrows.
///
/// Flutter mirrors the Material chevrons in a right-to-left layout, so
/// `Icons.chevron_left` is drawn pointing RIGHT in this app. Use these names
/// instead of picking a chevron by hand.
class AppIcons {
  const AppIcons._();

  /// "Open" / "next": points left in Arabic (where the next screen comes from).
  static const IconData forward = Icons.chevron_right;

  /// "Previous": points right in Arabic.
  static const IconData back = Icons.chevron_left;

  // The four activities of a Saturday, one icon each everywhere.
  static const IconData sundaySchool = Icons.menu_book_rounded;
  static const IconData vespers = Icons.nights_stay_rounded;
  static const IconData mass = Icons.church_rounded;
  static const IconData confession = Icons.record_voice_over_rounded;

  /// The servants' own meeting (اجتماع الخدام).
  static const IconData servantMeeting = Icons.groups_rounded;
}

/// Shared gradients used across the app.
class AppGradients {
  const AppGradients._();

  static const LinearGradient navyHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.navyDark, AppColors.navyLight],
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

/// The back button's face: the arrow on a soft rounded square.
class BackChip extends StatelessWidget {
  const BackChip({super.key});

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? AppColors.navy;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      // Turns by itself in a right-to-left layout.
      child: Icon(Icons.arrow_back_rounded, size: 20, color: color),
    );
  }
}

class AppTheme {
  const AppTheme._();

  /// Bundled with the app (assets/fonts), so text looks right offline too.
  static const fontFamily = 'Cairo';
  static const _font = fontFamily;

  /// The rounded bottom edge of the navy header. A tab strip under the header
  /// takes it over (see [headerRadius]).
  static const headerRadius =
      BorderRadius.vertical(bottom: Radius.circular(22));
  static const headerShape =
      RoundedRectangleBorder(borderRadius: headerRadius);

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
        // A soft shadow once the page scrolls under it.
        scrolledUnderElevation: 5,
        shadowColor: AppColors.navy.withValues(alpha: 0.35),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        shape: headerShape,
      ),
      // The back arrow sits on a soft rounded chip, in the header's colour.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const BackChip(),
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
          textStyle: TextStyle(
            fontFamily: _font,
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
        labelStyle:
            TextStyle(fontFamily: _font, fontSize: 13, color: AppColors.navy),
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
          TextStyle(
              fontFamily: _font, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EB), space: 1),
      // Opened screens keep a phone-like width on a wide window
      // (see CappedPageTransitionsBuilder); a phone sees no difference.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android:
              CappedPageTransitionsBuilder(SoftPageTransitionsBuilder()),
          TargetPlatform.iOS:
              CappedPageTransitionsBuilder(CupertinoPageTransitionsBuilder()),
          TargetPlatform.windows:
              CappedPageTransitionsBuilder(SoftPageTransitionsBuilder()),
          TargetPlatform.macOS:
              CappedPageTransitionsBuilder(SoftPageTransitionsBuilder()),
          TargetPlatform.linux:
              CappedPageTransitionsBuilder(SoftPageTransitionsBuilder()),
          TargetPlatform.fuchsia:
              CappedPageTransitionsBuilder(SoftPageTransitionsBuilder()),
        },
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      // Every date picker in the app: white and rounded like the other
      // dialogs, a navy header with white text (the grey default read as
      // disabled), a navy selected day, and an olive ring on today.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        headerBackgroundColor: AppColors.navy,
        headerForegroundColor: Colors.white,
        headerHeadlineStyle:
            const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        headerHelpStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        weekdayStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.muted),
        dayStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        yearStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          if (states.contains(WidgetState.disabled)) {
            return AppColors.muted.withValues(alpha: 0.45);
          }
          return AppColors.navyDark;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.navy : null),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.navyDark),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.navy : null),
        // Today uses its own colours even when it is the selected day, so
        // they must flip to white-on-navy too or the number disappears.
        todayForegroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.navy),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.navy : null),
        todayBorder: const BorderSide(color: AppColors.olive, width: 1.6),
        cancelButtonStyle:
            TextButton.styleFrom(foregroundColor: AppColors.muted),
        confirmButtonStyle:
            TextButton.styleFrom(foregroundColor: AppColors.navy),
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
