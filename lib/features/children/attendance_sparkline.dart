import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/attendance.dart';

/// The child's last Saturdays as small bars (height = share of the points
/// earned, red when absent), oldest on the left, with the dates under them.
/// Only Saturdays with a record are drawn: a Saturday nobody took attendance
/// for is not shown as an absence.
class AttendanceSparkline extends StatelessWidget {
  const AttendanceSparkline({super.key, required this.history, this.count = 10});

  final List<ChildSessionScore> history;
  final int count;

  /// The last [count] Saturdays up to [today], oldest first.
  static List<ChildSessionScore> lastSessions(
    List<ChildSessionScore> history,
    DateTime today, {
    int count = 10,
  }) {
    final cutoff = DateTime(today.year, today.month, today.day);
    final past = history.where((h) => !h.sessionDate.isAfter(cutoff)).toList()
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    return past.length <= count ? past : past.sublist(past.length - count);
  }

  /// Height of a bar between 0 and 1; an absence keeps a short stub so the
  /// Saturday is still visible.
  static double barFraction(ChildSessionScore s) {
    if (s.maxScore <= 0 || s.score <= 0) return 0.12;
    return (s.score / s.maxScore).clamp(0.12, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final shown = lastSessions(history, DateTime.now(), count: count);
    if (shown.length < 2) return const SizedBox.shrink();
    return SectionCard(
      title: AppStrings.attendanceTrend,
      icon: Icons.show_chart_rounded,
      accent: AppColors.sky,
      // Bars read oldest to newest, left to right, like the dashboard chart.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 84,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final s in shown)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: barFraction(s),
                              child: DecoratedBox(
                                key: ValueKey('bar|${s.sessionDate}'),
                                decoration: BoxDecoration(
                                  color: s.isPresent || s.score > 0
                                      ? AppColors.success
                                      : AppColors.danger,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const SizedBox(width: double.infinity),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${s.sessionDate.day}/${s.sessionDate.month}',
                          style: const TextStyle(
                              fontSize: 9, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
