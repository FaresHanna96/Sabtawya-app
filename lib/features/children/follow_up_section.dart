import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/reports.dart';
import 'child_profile_screen.dart';

/// "محتاجين متابعة": children who missed two or more Saturdays in a row, the
/// longest runs first. Hidden when nobody needs following up.
class FollowUpSection extends StatelessWidget {
  const FollowUpSection({
    super.key,
    required this.streaks,
    this.showClass = false,
    this.onReturn,
  });

  final List<ChildStreak> streaks;

  /// Show the class name too, for lists that span several classes.
  final bool showClass;

  /// Called after the profile screen closes, so the list can refresh.
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final absent = streaks.where((s) => s.absentStreak >= 2).toList()
      ..sort((a, b) {
        final byRun = b.absentStreak.compareTo(a.absentStreak);
        return byRun != 0 ? byRun : a.childName.compareTo(b.childName);
      });
    if (absent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SectionCard(
        title: '${AppStrings.needFollowUp} (${absent.length})',
        icon: Icons.support_agent_rounded,
        accent: AppColors.coral,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              AppStrings.needFollowUpHint,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            for (final s in absent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ChildProfileScreen(childId: s.childId),
                    ),
                  );
                  onReturn?.call();
                },
                title: Text(
                  s.childName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                subtitle: showClass ? Text(s.className) : null,
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${AppStrings.absentInARow} ${s.absentStreak} ${AppStrings.timesInARow}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.coral,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
