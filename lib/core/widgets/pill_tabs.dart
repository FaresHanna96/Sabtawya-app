import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's one tab switcher: a soft pill that slides under the open tab.
///
/// [onDark] is for a strip inside the navy header. [scrollable] lets long
/// labels scroll instead of being squeezed.
TabBar pillTabs({
  required List<Widget> tabs,
  TabController? controller,
  bool onDark = false,
  bool scrollable = false,
  EdgeInsetsGeometry? labelPadding,
}) {
  final accent = onDark ? Colors.white : AppColors.navy;
  return TabBar(
    controller: controller,
    tabs: tabs,
    isScrollable: scrollable,
    tabAlignment: scrollable ? TabAlignment.center : null,
    labelColor: accent,
    unselectedLabelColor:
        onDark ? Colors.white.withValues(alpha: 0.72) : AppColors.muted,
    indicatorSize: TabBarIndicatorSize.tab,
    indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    indicator: BoxDecoration(
      color: accent.withValues(alpha: onDark ? 0.18 : 0.10),
      borderRadius: BorderRadius.circular(14),
    ),
    dividerColor:
        onDark ? Colors.transparent : AppColors.navy.withValues(alpha: 0.08),
    // No hover or press grey: the pill is the feedback.
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    splashFactory: NoSplash.splashFactory,
    labelPadding:
        labelPadding ?? (scrollable ? null : EdgeInsets.zero),
    labelStyle: const TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 12.5,
      fontWeight: FontWeight.w800,
    ),
    unselectedLabelStyle: const TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    ),
  );
}
