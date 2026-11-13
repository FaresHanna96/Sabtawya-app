import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/reports.dart';

/// The dashboard's "الحضور كل سبت": attendance % of the last Saturdays
/// (children who came out of the active children of the classes recorded),
/// oldest on the right as Arabic reads, newest on the left.
class WeeklyAttendanceChart extends StatelessWidget {
  const WeeklyAttendanceChart({super.key, required this.weeks});

  final List<WeeklyAttendance> weeks;

  /// The last [count] Saturdays, oldest first.
  static List<WeeklyAttendance> lastWeeks(
    List<WeeklyAttendance> all, {
    int count = 10,
  }) =>
      all.length <= count ? all : all.sublist(all.length - count);

  @override
  Widget build(BuildContext context) {
    final shown = lastWeeks(weeks);
    if (shown.length < 2) return const SizedBox.shrink();
    final spots = [
      for (var i = 0; i < shown.length; i++)
        FlSpot(i.toDouble(), shown[i].percentage.clamp(0, 100).toDouble()),
    ];
    final last = shown.last.percentage.round();
    final before = shown[shown.length - 2].percentage.round();
    final diff = last - before;

    return SectionCard(
      title: AppStrings.weeklyAttendance,
      icon: Icons.show_chart_rounded,
      accent: AppColors.sky,
      trailing: Text(
        '$last%  ${diff == 0 ? '' : (diff > 0 ? '↑' : '↓')}${diff == 0 ? '' : diff.abs()}',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: diff >= 0 ? AppColors.success : AppColors.danger,
        ),
      ),
      child: SizedBox(
        height: 160,
        // Charts read left to right: oldest Saturday on the left.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.muted.withValues(alpha: 0.15),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: 50,
                    getTitlesWidget: (v, _) => Text(
                      '${v.round()}%',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if (i < 0 || i >= shown.length) {
                        return const SizedBox.shrink();
                      }
                      // Every other date, so they do not crowd.
                      if ((shown.length - 1 - i).isOdd) {
                        return const SizedBox.shrink();
                      }
                      final d = shown[i].date;
                      return Text(
                        '${d.day}/${d.month}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touched) => [
                    for (final t in touched)
                      LineTooltipItem(
                        '${shown[t.x.round()].present}/'
                        '${shown[t.x.round()].children}\n'
                        '${t.y.round()}%',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: AppColors.sky,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.sky.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
