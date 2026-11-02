import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'motion.dart';

/// The scenes available to [Illustration].
enum IllustrationKind {
  children,
  classes,
  attendance,
  activities,
  events,
  competitions,
  birthdays,
  search,
  error,
  offline,
  success,
  generic,
}

class _Scene {
  const _Scene(this.icon, this.color, this.tint, this.emoji, this.sparks);

  final IconData icon;
  final Color color;
  final Color tint;
  final String emoji;
  final List<IconData> sparks;
}

const _scenes = <IllustrationKind, _Scene>{
  IllustrationKind.children: _Scene(Icons.child_care, AppColors.navy,
      AppColors.navyTint, '🧒', [Icons.star_rounded, Icons.favorite_rounded]),
  IllustrationKind.classes: _Scene(Icons.menu_book_rounded, AppColors.olive,
      AppColors.oliveTint, '📚', [Icons.star_rounded, Icons.edit_rounded]),
  IllustrationKind.attendance: _Scene(Icons.fact_check_rounded, AppColors.sky,
      AppColors.skyTint, '✅', [Icons.star_rounded, Icons.access_time_rounded]),
  IllustrationKind.activities: _Scene(
      Icons.volunteer_activism_rounded,
      AppColors.coral,
      AppColors.coralTint,
      '🤝',
      [Icons.favorite_rounded, Icons.star_rounded]),
  IllustrationKind.events: _Scene(Icons.celebration_rounded, AppColors.gold,
      AppColors.goldTint, '🎉', [Icons.star_rounded, Icons.music_note_rounded]),
  IllustrationKind.competitions: _Scene(Icons.emoji_events_rounded,
      AppColors.gold, AppColors.goldTint, '🏆', [Icons.star_rounded]),
  IllustrationKind.birthdays: _Scene(Icons.cake_rounded, AppColors.coral,
      AppColors.coralTint, '🎂', [Icons.star_rounded, Icons.favorite_rounded]),
  IllustrationKind.search: _Scene(Icons.search_rounded, AppColors.navyLight,
      AppColors.navyTint, '🔍', [Icons.star_rounded]),
  IllustrationKind.error: _Scene(Icons.cloud_off_rounded, AppColors.danger,
      AppColors.coralTint, '😕', [Icons.priority_high_rounded]),
  IllustrationKind.offline: _Scene(Icons.wifi_off_rounded, AppColors.warning,
      AppColors.goldTint, '📡', [Icons.priority_high_rounded]),
  IllustrationKind.success: _Scene(Icons.check_circle_rounded,
      AppColors.success, AppColors.oliveTint, '🎉', [Icons.star_rounded]),
  IllustrationKind.generic: _Scene(Icons.inbox_rounded, AppColors.navy,
      AppColors.navyTint, '🌱', [Icons.star_rounded]),
};

/// A friendly drawn scene: a soft tinted disc, a big icon, a floating emoji and
/// a few sparkles. Built from shapes so it works offline and matches the palette.
class Illustration extends StatelessWidget {
  const Illustration(this.kind, {super.key, this.size = 150});

  final IllustrationKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = _scenes[kind]!;
    final disc = size * 0.78;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: disc,
            height: disc,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.white, s.tint],
                stops: const [0.15, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: s.color.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
          Float(
            child: Container(
              padding: EdgeInsets.all(size * 0.14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [s.color, s.color.withValues(alpha: 0.7)],
                ),
              ),
              child: Icon(s.icon, size: size * 0.26, color: Colors.white),
            ),
          ),
          PositionedDirectional(
            top: size * 0.02,
            end: size * 0.06,
            child: Pulse(
              child: Text(s.emoji, style: TextStyle(fontSize: size * 0.2)),
            ),
          ),
          for (var i = 0; i < s.sparks.length; i++)
            PositionedDirectional(
              bottom: size * (0.08 + 0.1 * i),
              start: size * (0.04 + 0.12 * i),
              child: Pulse(
                duration: Duration(milliseconds: 1300 + 400 * i),
                child: Icon(
                  s.sparks[i],
                  size: size * (0.11 + 0.02 * i),
                  color: (i.isEven ? AppColors.gold : s.color)
                      .withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
