import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
import '../dashboard/weekly_attendance_chart.dart';

/// "اتسجّل حضور 21 نوفمبر" with who came ("حضر 8 من 10", 80%), or
/// "لم يُسجَّل بعد" with a button to do it.
class ClassSaturdayStatus extends StatelessWidget {
  const ClassSaturdayStatus({
    super.key,
    required this.recorded,
    required this.day,
    required this.onRecord,
    this.present,
    this.children,
  });

  final bool recorded;
  final String day;
  final VoidCallback onRecord;

  /// Who came out of the class's active children; shown once recorded.
  final int? present;
  final int? children;

  @override
  Widget build(BuildContext context) {
    final color = recorded ? AppColors.success : AppColors.warning;
    final total = children ?? 0;
    if (recorded && present != null && total > 0) {
      final pct = present! / total * 100;
      final level = WeeklyAttendanceChart.levelColor(pct);
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                // What the bar is: this Saturday's attendance.
                Expanded(
                  child: Text(
                    AppStrings.classWeekAttendance(day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.readable(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // "8/10 • 80%": who came out of the class, then the share.
                Text(
                  '$present/$total',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${pct.round()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.readable(level),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              // Fills from empty when the page opens (still, with reduced
              // motion).
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: (pct / 100).clamp(0.0, 1.0)),
                duration: reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  backgroundColor: AppColors.navy.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(level),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            recorded
                ? Icons.check_circle_rounded
                : Icons.pending_actions_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              recorded
                  ? AppStrings.classRecordedOn(day)
                  : AppStrings.classNotRecordedOn(day),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.readable(color),
              ),
            ),
          ),
          if (!recorded)
            TextButton(
              onPressed: onRecord,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.navy,
                minimumSize: const Size(0, 40),
              ),
              child: const Text(AppStrings.recordNow),
            )
          else
            const SizedBox(height: 40),
        ],
      ),
    );
  }
}
