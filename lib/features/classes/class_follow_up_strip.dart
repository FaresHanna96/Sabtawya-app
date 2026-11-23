import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';

/// «متابعة الفصل»: one tinted chip per thing that needs a look in this class
/// (repeated absence, birthdays this month, missing details), each with its
/// count. The committed children («أبطال الالتزام») are in the ranking card.
/// A chip at zero is left out; with all three at zero nothing shows. A tap
/// opens the matching screen for this class.
class ClassFollowUpStrip extends StatelessWidget {
  const ClassFollowUpStrip({
    super.key,
    required this.absent,
    required this.birthdays,
    required this.missing,
    required this.onAbsent,
    required this.onBirthdays,
    required this.onMissing,
  });

  final int absent;
  final int birthdays;
  final int missing;
  final VoidCallback onAbsent;
  final VoidCallback onBirthdays;
  final VoidCallback onMissing;

  bool get isEmpty => absent <= 0 && birthdays <= 0 && missing <= 0;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    final tiles = <Widget>[
      if (absent > 0)
        _Tile(
          icon: Icons.phone_in_talk_rounded,
          count: absent,
          label: AppStrings.followAbsent,
          color: AppColors.coral,
          onTap: onAbsent,
        ),
      if (birthdays > 0)
        _Tile(
          icon: Icons.cake_rounded,
          count: birthdays,
          label: AppStrings.followBirthdays,
          color: AppColors.gold,
          onTap: onBirthdays,
        ),
      if (missing > 0)
        _Tile(
          icon: Icons.edit_note_rounded,
          count: missing,
          label: AppStrings.followMissing,
          color: AppColors.sky,
          onTap: onMissing,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            AppStrings.classFollowUp,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        // Equal tiles on one row: the count first, then what it is.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.readable(color);
    return Material(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: text),
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
