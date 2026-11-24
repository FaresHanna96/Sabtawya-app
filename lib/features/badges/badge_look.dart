import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/badges.dart';

/// How a badge looks and reads: its name, its rule, its icon and colour.
extension KidBadgeLook on KidBadge {
  String get title => switch (this) {
        KidBadge.streak4 => AppStrings.badgeStreak4,
        KidBadge.massMonth => AppStrings.badgeMassMonth,
        KidBadge.vespersMonth => AppStrings.badgeVespersMonth,
        KidBadge.fullDay => AppStrings.badgeFullDay,
        KidBadge.confession3 => AppStrings.badgeConfession3,
        KidBadge.starMonth => AppStrings.badgeStarMonth,
        KidBadge.starYear => AppStrings.badgeStarYear,
        KidBadge.starSchool => AppStrings.badgeStarSchool,
        KidBadge.streak16 => AppStrings.badgeStreak16,
      };

  String get rule => switch (this) {
        KidBadge.streak4 => AppStrings.badgeStreak4Rule,
        KidBadge.massMonth => AppStrings.badgeMassMonthRule,
        KidBadge.vespersMonth => AppStrings.badgeVespersMonthRule,
        KidBadge.fullDay => AppStrings.badgeFullDayRule,
        KidBadge.confession3 => AppStrings.badgeConfession3Rule,
        KidBadge.starMonth => AppStrings.badgeStarMonthRule,
        KidBadge.starYear => AppStrings.badgeStarYearRule,
        KidBadge.starSchool => AppStrings.badgeStarSchoolRule,
        KidBadge.streak16 => AppStrings.badgeStreak16Rule,
      };

  IconData get icon => switch (this) {
        KidBadge.streak4 => Icons.local_fire_department_rounded,
        KidBadge.massMonth => Icons.church_rounded,
        KidBadge.vespersMonth => Icons.wb_twilight_rounded,
        KidBadge.fullDay => Icons.event_available_rounded,
        KidBadge.confession3 => Icons.favorite_rounded,
        KidBadge.starMonth => Icons.star_rounded,
        KidBadge.starYear => Icons.military_tech_rounded,
        KidBadge.starSchool => Icons.workspace_premium_rounded,
        KidBadge.streak16 => Icons.whatshot_rounded,
      };

  /// The badge's colour (icon and its disc); text uses its readable shade.
  Color get color => switch (this) {
        KidBadge.streak4 => AppColors.gold,
        KidBadge.massMonth => AppColors.navy,
        KidBadge.vespersMonth => AppColors.coral,
        KidBadge.fullDay => AppColors.olive,
        KidBadge.confession3 => AppColors.coral,
        KidBadge.starMonth => AppColors.sky,
        KidBadge.starYear => AppColors.maroon,
        KidBadge.starSchool => AppColors.gold,
        KidBadge.streak16 => AppColors.gold,
      };
}

extension GameLevelLook on GameLevel {
  String get title => switch (this) {
        GameLevel.seed => AppStrings.levelSeed,
        GameLevel.sprout => AppStrings.levelSprout,
        GameLevel.tree => AppStrings.levelTree,
        GameLevel.fruit => AppStrings.levelFruit,
      };

  IconData get icon => switch (this) {
        GameLevel.seed => Icons.grain_rounded,
        GameLevel.sprout => Icons.spa_rounded,
        GameLevel.tree => Icons.park_rounded,
        GameLevel.fruit => Icons.local_florist_rounded,
      };
}

/// A badge's round medal: coloured when earned, grey with a lock when not.
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({
    super.key,
    required this.badge,
    required this.earned,
    this.size = 48,
  });

  final KidBadge badge;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = earned ? badge.color : AppColors.muted;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned
            ? statusTint(badge.color, 0.16)
            : AppColors.muted.withValues(alpha: 0.10),
      ),
      child: Icon(
        earned ? badge.icon : Icons.lock_outline_rounded,
        size: size * 0.52,
        color: earned ? color : color.withValues(alpha: 0.7),
      ),
    );
  }
}
