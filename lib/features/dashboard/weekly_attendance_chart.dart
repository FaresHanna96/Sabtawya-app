import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/reports.dart';

/// The dashboard's "الحضور كل سبت".
///
/// - The big numbers are about one named Saturday: the latest one recorded
///   and finished (today only once every class has recorded).
/// - One bar per Saturday, oldest on the left: % on top, date below. A
///   Saturday nobody recorded shows «—», a week with no lesson «إجازة», so a
///   gap is seen instead of vanishing. A dashed line marks the 60% target.
/// - Tapping a bar shows that Saturday: its numbers, each class lowest first
///   (when there is more than one), and the classes that did not record as
///   chips that open their attendance ([onRecord]).
/// - [benchmark] (the servant's page) adds the whole service's % to compare.
class WeeklyAttendanceChart extends StatefulWidget {
  const WeeklyAttendanceChart({
    super.key,
    required this.weeks,
    this.classNames = const {},
    this.benchmark = const {},
    this.onRecord,
  });

  final List<WeeklyAttendance> weeks;

  /// Class id to name, in the usual class order.
  final Map<String, String> classNames;

  /// The whole service's % per Saturday; empty hides the comparison.
  final Map<DateTime, double> benchmark;

  /// Opens attendance for a class that did not record that Saturday.
  final void Function(String classId, DateTime date)? onRecord;

  /// The target the dashed line marks; also where a bar turns green.
  static const goal = 60.0;

  /// The last [count] Saturdays, oldest first.
  static List<WeeklyAttendance> lastWeeks(
    List<WeeklyAttendance> all, {
    int count = 10,
  }) =>
      all.length <= count ? all : all.sublist(all.length - count);

  /// Green from 60%, amber from 40%, red below.
  static Color levelColor(double pct) => pct >= goal
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

  double? _bench(DateTime d) =>
      widget.benchmark[DateTime(d.year, d.month, d.day)];

  /// [ids] in the usual class order, any unknown ones last.
  List<String> _ordered(Iterable<String> ids) {
    final set = ids.toSet();
    return [
      for (final id in widget.classNames.keys)
        if (set.contains(id)) id,
      for (final id in set)
        if (!widget.classNames.containsKey(id)) id,
    ];
  }

  String _name(String id) => widget.classNames[id] ?? '—';

  @override
  Widget build(BuildContext context) {
    final shown = WeeklyAttendanceChart.lastWeeks(widget.weeks);
    final head = WeeklyAttendance.headline(shown);
    if (head == null) return const SizedBox.shrink();
    final prev = WeeklyAttendance.previous(shown, head);
    final missed = WeeklyAttendance.missedAfter(shown, head);
    final today = shown.last.inProgress ? shown.last : null;
    final picked = (_picked ?? shown.length - 1).clamp(0, shown.length - 1);

    return SectionCard(
      title: AppStrings.weeklyAttendance,
      icon: Icons.bar_chart_rounded,
      accent: AppColors.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headline(head),
          if (prev != null) _trend(head, prev),
          if (missed.isNotEmpty)
            _note(
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
              text: AppStrings.saturdaysMissed(
                  [for (final w in missed) _date(w.date)]),
              onTap: () => setState(() => _picked = shown.indexOf(missed.last)),
            ),
          // Said once: not here while the box below already shows today.
          if (today != null && picked != shown.length - 1)
            _note(
              icon: Icons.schedule_rounded,
              color: AppColors.muted,
              text: today.recorded
                  ? AppStrings.todayProgress(
                      today.perClass.where((c) => c.recorded).length,
                      today.perClass.length,
                    )
                  : AppStrings.todayNoneYet,
              onTap: () => setState(() => _picked = shown.length - 1),
            ),
          const SizedBox(height: 14),
          // Bars read left to right: oldest Saturday on the left.
          Directionality(
            textDirection: TextDirection.ltr,
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
          const SizedBox(height: 8),
          const _Legend(),
          const SizedBox(height: 10),
          // The tapped Saturday (the newest until one is tapped).
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(picked),
              child: _detail(shown[picked]),
            ),
          ),
        ],
      ),
    );
  }

  /// «حضروا سبت 7/11» over «84 من 165 مخدوم», the % beside it.
  Widget _headline(WeeklyAttendance w) {
    final level = WeeklyAttendanceChart.levelColor(w.percentage);
    final bench = _bench(w.date);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.attendedOn(_date(w.date)),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.attendedOf(w.present, w.children),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              if (bench != null)
                Text(
                  AppStrings.serviceWide(bench.round()),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: level.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${w.percentage.round()}%',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.readable(level),
            ),
          ),
        ),
      ],
    );
  }

  /// Up or down from the recorded Saturday before, in points.
  Widget _trend(WeeklyAttendance w, WeeklyAttendance prev) {
    final diff = WeeklyAttendance.pointsChange(w, prev);
    final color = diff > 0
        ? AppColors.success
        : diff < 0
            ? AppColors.danger
            : AppColors.muted;
    return _note(
      icon: diff > 0
          ? Icons.trending_up_rounded
          : diff < 0
              ? Icons.trending_down_rounded
              : Icons.trending_flat_rounded,
      color: color,
      text: AppStrings.pointsChange(
        diff,
        prev.percentage.round(),
        w.percentage.round(),
      ),
    );
  }

  Widget _note({
    required IconData icon,
    required Color color,
    required String text,
    VoidCallback? onTap,
  }) {
    final row = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.readable(color),
              ),
            ),
          ),
        ],
      ),
    );
    return onTap == null
        ? row
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: row,
          );
  }

  /// One Saturday in full: what happened, each class, who did not record.
  Widget _detail(WeeklyAttendance w) {
    final date = _date(w.date);
    final String line;
    if (!w.recorded) {
      line = w.isBreak
          ? AppStrings.weekBreak(date)
          : w.isToday
              ? AppStrings.todayNoneYet
              : AppStrings.weekNotRecorded(date);
    } else {
      line = AppStrings.saturdayDetail(
        date,
        w.present,
        w.children,
        w.percentage.round(),
      );
    }
    final bench = w.recorded ? _bench(w.date) : null;
    final recordedClasses = [
      for (final c in w.perClass)
        if (c.recorded) c,
    ]..sort((a, b) => a.percentage.compareTo(b.percentage));
    // On a Saturday nobody recorded, every class is missing; a holiday
    // nobody recorded needs no reminder.
    final missing = w.isBreak && !w.recorded
        ? const <String>[]
        : _ordered(w.missingClassIds);

    return Container(
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
                  line,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (bench != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 22, top: 2),
              child: Text(
                AppStrings.serviceWide(bench.round()),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          // Each class, lowest first, when there is more than one.
          if (recordedClasses.length > 1) ...[
            const SizedBox(height: 8),
            for (final c in recordedClasses)
              _ClassLine(name: _name(c.classId), pct: c.percentage),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              w.isToday
                  ? AppStrings.stillRecording
                  : AppStrings.notRecordedLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: w.isToday ? AppColors.muted : AppColors.warning,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in missing)
                  widget.onRecord == null
                      ? Chip(
                          label: Text(_name(id)),
                          visualDensity: VisualDensity.compact,
                        )
                      : ActionChip(
                          avatar: const Icon(Icons.edit_calendar_outlined,
                              size: 16),
                          label: Text(_name(id)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => widget.onRecord!(id, w.date),
                        ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "3 ولاد ▬▬▬▬── 40%": one class on the tapped Saturday.
class _ClassLine extends StatelessWidget {
  const _ClassLine({required this.name, required this.pct});

  final String name;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final color = WeeklyAttendanceChart.levelColor(pct);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0, 1),
                minHeight: 6,
                color: color,
                backgroundColor: AppColors.muted.withValues(alpha: 0.12),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${pct.round()}%',
              textAlign: TextAlign.end,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.readable(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ● 60% وأكثر  ● 40–59%  ● أقل من 40%  ┄ الهدف 60%
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: c),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        dot(AppColors.success, AppStrings.legendHigh),
        dot(AppColors.warning, AppStrings.legendMid),
        dot(AppColors.danger, AppStrings.legendLow),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 8,
              child: CustomPaint(painter: _DashPainter(atBottom: 4)),
            ),
            const SizedBox(width: 4),
            const Text(AppStrings.goalLine,
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
}

/// One Saturday: the bar growing from the bottom with its % (or «—», or
/// «إجازة») on top, the date below; the 60% line drawn behind it.
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

  static const maxBar = 110.0;

  /// Room above a full bar for its label.
  static const _region = maxBar + 18;

  @override
  Widget build(BuildContext context) {
    final recorded = week.recorded;
    final pct = recorded ? week.percentage.clamp(0, 100).toDouble() : 0.0;
    final color =
        recorded ? WeeklyAttendanceChart.levelColor(pct) : AppColors.muted;
    final label = recorded
        ? '${pct.round()}%'
        : week.isBreak
            ? AppStrings.breakShort
            : '—';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: _region,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) {
                final h = recorded ? (maxBar * v).clamp(4.0, maxBar) : 10.0;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DashPainter(
                          atBottom: maxBar * WeeklyAttendanceChart.goal / 100,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 3,
                      right: 3,
                      bottom: 0,
                      height: h,
                      child: Container(
                        decoration: BoxDecoration(
                          color: recorded
                              ? (selected
                                  ? color
                                  : color.withValues(
                                      alpha: week.isToday ? 0.25 : 0.45))
                              : week.isBreak
                                  ? AppColors.muted.withValues(alpha: 0.25)
                                  : null,
                          border: recorded || week.isBreak
                              ? null
                              : Border.all(
                                  color: selected
                                      ? AppColors.warning
                                      : AppColors.muted.withValues(alpha: 0.5),
                                ),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: h + 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected ? color : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              week.isToday ? AppStrings.todayBar : date,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? AppColors.navy : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dashed line [atBottom] pixels above the bottom edge.
class _DashPainter extends CustomPainter {
  const _DashPainter({required this.atBottom});

  final double atBottom;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final y = size.height - atBottom;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + 4).clamp(0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.atBottom != atBottom;
}
