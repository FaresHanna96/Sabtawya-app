import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';

/// One servant's activity summary as tiles: attendance in each activity out of
/// the sessions already held, plus lesson preps. Shown on the servant's own
/// screen and on the admin's per-servant screen, so both read the same.
class ServantSummaryCard extends StatelessWidget {
  const ServantSummaryCard({
    super.key,
    required this.sundaySchool,
    required this.servantMeeting,
    required this.mass,
    required this.confession,
    required this.preps,
    required this.pendingPreps,
    required this.heldSessions,
  });

  final int sundaySchool;
  final int servantMeeting;
  final int mass;
  final int confession;
  final int preps;
  final int pendingPreps;

  /// Sessions already held (one per date): the base of every percentage.
  final int heldSessions;

  String _pct(int n) =>
      heldSessions == 0 ? '' : ' (${(n / heldSessions * 100).round()}%)';

  Widget _row(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: a),
            const SizedBox(width: 8),
            Expanded(child: b),
          ],
        ),
      );

  StatTile _attendance(
    String label,
    int count,
    Color color,
    IconData icon,
  ) =>
      StatTile(
        label: '$label${_pct(count)}',
        value: '$count/$heldSessions',
        color: color,
        icon: icon,
      );

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: AppStrings.servantActivityReport,
      icon: Icons.insert_chart_rounded,
      accent: AppColors.navy,
      child: Column(
        children: [
          _row(
            _attendance(AppStrings.sundaySchoolShort, sundaySchool,
                AppColors.success, Icons.church_outlined),
            _attendance(AppStrings.servantMeetingShort, servantMeeting,
                AppColors.success, Icons.groups_outlined),
          ),
          _row(
            _attendance(AppStrings.mass, mass, AppColors.gold,
                Icons.account_balance_outlined),
            _attendance(AppStrings.confession, confession, AppColors.coral,
                Icons.volunteer_activism_outlined),
          ),
          _row(
            StatTile(
              label: AppStrings.lessonPrep,
              value: '$preps',
              color: AppColors.navy,
              icon: Icons.assignment_outlined,
            ),
            StatTile(
              label: AppStrings.prepPending,
              value: '$pendingPreps',
              color: pendingPreps > 0 ? AppColors.warning : AppColors.muted,
              icon: Icons.hourglass_empty_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
