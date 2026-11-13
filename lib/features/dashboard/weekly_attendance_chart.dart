import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/reports.dart';

/// The dashboard's "الحضور كل سبت": the last Saturday in plain words (who
/// came, and up or down from the Saturday before), then one labelled bar per
/// Saturday (% on top, date below) coloured by level. Tapping a bar shows
/// that Saturday's numbers. Oldest on the left, newest on the right.
class WeeklyAttendanceChart extends StatefulWidget {
  const WeeklyAttendanceChart({
    super.key,
    required this.weeks,
    this.top,
    this.classNames = const {},
  });

  /// Class id to name, in the usual class order, for naming the classes
  /// that did not record a Saturday.
  final Map<String, String> classNames;

  final List<WeeklyAttendance> weeks;

  /// Shown above the numbers inside the same card (the dashboard puts the
  /// last Saturday taken here).
  final Widget? top;

  /// The last [count] Saturdays, oldest first.
  static List<WeeklyAttendance> lastWeeks(
    List<WeeklyAttendance> all, {
    int count = 10,
  }) =>
      all.length <= count ? all : all.sublist(all.length - count);

  /// Green from 60%, amber from 40%, red below.
  static Color levelColor(double pct) => pct >= 60
      ? AppColors.success
      : pct >= 40
          ? AppColors.warning
          : AppColors.danger;

  @override
  State<WeeklyAttendanceChart> createState() => _WeeklyAttendanceChartState();
}

class _WeeklyAttendanceChartState extends State<WeeklyAttendanceChart> {
  /// The bar tapped; null shows the newest Saturday.
  int? _picked;

  static String _date(DateTime d) => '${d.day}/${d.month}';

  /// Names of the classes that did not record, in the usual class order.
  List<String> _missingNames(WeeklyAttendance w) {
    if (w.missingClassIds.isEmpty) return const [];
    return [
      for (final e in widget.classNames.entries)
        if (w.missingClassIds.contains(e.key)) e.value,
    ];
  }

  Widget _missingLine(List<String> names) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: AppColors.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                AppStrings.notRecordedClasses(names),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final shown = WeeklyAttendanceChart.lastWeeks(widget.weeks);
    if (shown.length < 2) return const SizedBox.shrink();
    final newest = shown.last;
    final pct = newest.percentage.round();
    final diff = pct - shown[shown.length - 2].percentage.round();
    final picked = (_picked ?? shown.length - 1).clamp(0, shown.length - 1);
    final p = shown[picked];
    final newestMissing = _missingNames(newest);
    final pickedMissing = _missingNames(p);
    final level = WeeklyAttendanceChart.levelColor(newest.percentage);
    final trend = diff > 0
        ? AppColors.success
        : diff < 0
            ? AppColors.danger
            : AppColors.muted;

    return SectionCard(
      title: AppStrings.weeklyAttendance,
      icon: Icons.bar_chart_rounded,
      accent: AppColors.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.top != null) ...[
            widget.top!,
            const SizedBox(height: 10),
          ],
          // The newest Saturday in big, plain numbers.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppStrings.attendedLastSaturday,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.attendedOf(newest.present, newest.children),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: level.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pct%',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: level,
                  ),
                ),
              ),
            ],
          ),
          if (newestMissing.isNotEmpty) _missingLine(newestMissing),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                diff > 0
                    ? Icons.trending_up_rounded
                    : diff < 0
                        ? Icons.trending_down_rounded
                        : Icons.trending_flat_rounded,
                size: 18,
                color: trend,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppStrings.comparedToPrevious(diff),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: trend,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bars read left to right: oldest Saturday on the left.
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Expanded(
                      child: _Bar(
                        week: shown[i],
                        date: _date(shown[i].date),
                        selected: i == picked,
                        onTap: () => setState(() => _picked = i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // The tapped Saturday (the newest until one is tapped).
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(picked),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.sky.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.touch_app_outlined,
                          size: 16, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          AppStrings.saturdayDetail(
                            _date(p.date),
                            p.present,
                            p.children,
                            p.percentage.round(),
                          ),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (pickedMissing.isNotEmpty) _missingLine(pickedMissing),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One Saturday: the % above, a bar growing from the bottom, the date below.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.week,
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final WeeklyAttendance week;
  final String date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = week.percentage.clamp(0, 100).toDouble();
    final color = WeeklyAttendanceChart.levelColor(pct);
    const maxBar = 96.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FittedBox(
              child: Text(
                '${pct.round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? color : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Container(
                height: (maxBar * v).clamp(4, maxBar),
                decoration: BoxDecoration(
                  color: selected ? color : color.withValues(alpha: 0.45),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                date,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? AppColors.navy : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
