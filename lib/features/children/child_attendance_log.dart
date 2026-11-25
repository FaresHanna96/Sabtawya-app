import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/attendance.dart';
import '../../data/models/badges.dart';
import '../../data/models/reports.dart';

/// One Saturday in a child's log: its record, or none when the class's
/// attendance was not taken that day. A Saturday with no lesson (إجازة /
/// نشاط ترفيهي) is listed as such and counts for nothing, even if something
/// was saved on it.
class LogSaturday {
  const LogSaturday(this.date, this.score, {this.isBreak = false});

  final DateTime date;
  final ChildSessionScore? score;
  final bool isBreak;

  bool get recorded => score != null && !isBreak;
  bool get present => recorded && score!.isPresent;
  bool get absent => recorded && !present;
}

/// One month of a child's log. Saturdays nobody recorded are kept only to
/// say how many there were: a class that did not take attendance is not the
/// child's absence, so they are neither listed nor counted.
class LogMonth {
  const LogMonth(this.month, this.saturdays);

  /// The 1st of the month.
  final DateTime month;

  /// Newest first, recorded or not.
  final List<LogSaturday> saturdays;

  /// The recorded Saturdays (the ones that count), newest first.
  List<LogSaturday> get recorded => [
        for (final s in saturdays)
          if (s.recorded) s,
      ];

  /// What the month lists: the recorded Saturdays and the no-lesson ones.
  List<LogSaturday> get listed => [
        for (final s in saturdays)
          if (s.recorded || s.isBreak) s,
      ];

  int get held => recorded.length;
  int get attended => saturdays.where((s) => s.present).length;
  int get notRecorded =>
      saturdays.where((s) => !s.recorded && !s.isBreak).length;
  int get noLesson => saturdays.where((s) => s.isBreak).length;
  int get points => recorded.fold(0, (sum, s) => sum + s.score!.score);

  /// Attended out of held, or null when nothing was recorded.
  double? get ratio => held == 0 ? null : attended / held;

  /// The child's Saturdays this year, by month, newest month first: every
  /// record in [history], plus the class's Saturdays in [sessionDates] up to
  /// [today] that have none.
  static List<LogMonth> build({
    required List<ChildSessionScore> history,
    required List<DateTime> sessionDates,
    required DateTime today,
    Set<DateTime> breakDates = const {},
  }) {
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    final cutoff = day(today);
    final noLesson = {for (final d in breakDates) day(d)};
    final byDay = <DateTime, ChildSessionScore?>{};
    for (final d in sessionDates) {
      final k = day(d);
      if (!k.isAfter(cutoff)) byDay[k] = null;
    }
    // A record wins over an empty Saturday of the same day (and a child who
    // changed class keeps the Saturdays of the old one).
    for (final h in history) {
      byDay[day(h.sessionDate)] = h;
    }

    final byMonth = <DateTime, List<LogSaturday>>{};
    for (final e in byDay.entries) {
      (byMonth[DateTime(e.key.year, e.key.month)] ??= []).add(LogSaturday(
        e.key,
        e.value,
        isBreak: noLesson.contains(e.key) || (e.value?.isBreak ?? false),
      ));
    }
    final months = [
      for (final e in byMonth.entries)
        LogMonth(e.key, e.value..sort((a, b) => b.date.compareTo(a.date))),
    ]..sort((a, b) => b.month.compareTo(a.month));
    return months;
  }
}

/// The whole year at a glance, from the same Saturdays as the months.
class LogTotals {
  const LogTotals({
    required this.held,
    required this.attended,
    required this.perActivity,
  });

  /// Recorded Saturdays so far.
  final int held;
  final int attended;

  /// Saturdays each activity was done.
  final Map<LogActivity, int> perActivity;

  double? get ratio => held == 0 ? null : attended / held;

  factory LogTotals.of(List<LogMonth> months) {
    final days = [
      for (final m in months) ...m.recorded,
    ];
    return LogTotals(
      held: days.length,
      attended: days.where((s) => s.present).length,
      perActivity: {
        for (final a in LogActivity.values)
          a: days.where((s) => a.on(s.score!)).length,
      },
    );
  }
}

/// The four activities of a Saturday, as the log shows them.
enum LogActivity {
  sundaySchool(
      AppStrings.sundaySchoolShort, AppIcons.sundaySchool, AppColors.success),
  vespers(AppStrings.vespersShort, AppIcons.vespers, AppColors.sky),
  mass(AppStrings.massShort, AppIcons.mass, AppColors.gold),
  confession(AppStrings.confessionShort, AppIcons.confession, AppColors.coral);

  const LogActivity(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  bool on(ChildSessionScore s) => switch (this) {
        LogActivity.sundaySchool => s.sundaySchool,
        LogActivity.vespers => s.vespers,
        LogActivity.mass => s.mass,
        LogActivity.confession => s.confession,
      };

  /// When this activity was last done, never later than [today]: a Saturday
  /// marked ahead of time is not "the last time" (it used to read «اليوم»).
  /// The database's date [db] is used as it is, unless it lies in the future;
  /// then the latest Saturday up to today in the child's own [months] where
  /// the activity was done stands in (null when there is none).
  DateTime? lastDone(
    List<LogMonth> months,
    DateTime? db,
    DateTime today,
  ) {
    if (db == null) return null;
    final cutoff = DateTime(today.year, today.month, today.day);
    if (!DateTime(db.year, db.month, db.day).isAfter(cutoff)) return db;
    DateTime? best;
    for (final m in months) {
      for (final s in m.recorded) {
        if (s.date.isAfter(cutoff) || !on(s.score!)) continue;
        if (best == null || s.date.isAfter(best)) best = s.date;
      }
    }
    return best;
  }

  DateTime? lastIn(ChildLastActivity a) => switch (this) {
        LogActivity.sundaySchool => a.lastSundaySchool,
        LogActivity.vespers => a.lastVespers,
        LogActivity.mass => a.lastMass,
        LogActivity.confession => a.lastConfession,
      };
}

/// Which Saturdays the log lists.
enum LogFilter { all, present, absent }

/// A child's attendance, all in one card on the profile: the year's average
/// and points, each activity with its count and the last time it was done,
/// then month by month (newest first) with "حضر 1 من 3" and a bar, each
/// opening to its Saturdays, one line each with the four activities as icons.
class ChildAttendanceLog extends StatefulWidget {
  const ChildAttendanceLog({
    super.key,
    required this.history,
    required this.sessionDates,
    this.breakDates = const {},
    this.lastActivity,
    this.points,
    this.gamePoints,
    this.badges = const <ChildBadge>[],
    this.today,
  });

  /// The year's طايو with the badges' bonus, as the class ranking counts it
  /// (the profile header's number). Wins over [points] + the bonus.
  final int? gamePoints;

  final List<ChildSessionScore> history;

  /// The class's Saturdays this year (also those with no record).
  final List<DateTime> sessionDates;

  /// Saturdays with no lesson: listed as such, never counted.
  final Set<DateTime> breakDates;

  /// When each activity was last done (any year).
  final ChildLastActivity? lastActivity;

  /// The year's attendance points as the database counts them; summed from
  /// [history] when not given. The badges' bonus is added on top.
  final int? points;

  /// The child's badges: each one earned adds [kBadgeBonus] to the year's
  /// طايو and to the month it was earned in.
  final List<ChildBadge> badges;

  /// Defaults to now; tests pin it.
  final DateTime? today;

  @override
  State<ChildAttendanceLog> createState() => _ChildAttendanceLogState();
}

class _ChildAttendanceLogState extends State<ChildAttendanceLog> {
  LogFilter _filter = LogFilter.all;

  /// «سجل الحضور», the list under the summary, folded or open.
  bool _historyOpen = true;

  /// Months the user opened or closed; until then only the newest month with
  /// a recorded Saturday is open.
  final Map<DateTime, bool> _open = {};

  late List<LogMonth> _months = _build();

  List<LogMonth> _build() => LogMonth.build(
        history: widget.history,
        sessionDates: widget.sessionDates,
        breakDates: widget.breakDates,
        today: widget.today ?? DateTime.now(),
      );

  @override
  void didUpdateWidget(ChildAttendanceLog old) {
    super.didUpdateWidget(old);
    if (old.history != widget.history ||
        old.sessionDates != widget.sessionDates ||
        old.breakDates != widget.breakDates) {
      _months = _build();
    }
  }

  /// The badges' bonus by the month each was earned in (the 1st of it).
  Map<DateTime, int> get _bonusByMonth {
    final out = <DateTime, int>{};
    for (final b in widget.badges) {
      final on = b.earnedOn;
      if (on == null) continue;
      final month = DateTime(on.year, on.month);
      out[month] = (out[month] ?? 0) + kBadgeBonus;
    }
    return out;
  }

  bool _isOpen(LogMonth m) {
    final asked = _open[m.month];
    if (asked != null) return asked;
    for (final x in _months) {
      if (x.held > 0) return identical(x, m);
    }
    return false;
  }

  bool _matches(LogSaturday s) => switch (_filter) {
        LogFilter.all => true,
        LogFilter.present => s.present,
        LogFilter.absent => s.absent,
      };

  @override
  Widget build(BuildContext context) {
    final totals = LogTotals.of(_months);
    // The same figure as the profile's header when it is known, so the two
    // can never differ; otherwise the attendance points plus the badge bonus.
    final points = widget.gamePoints ??
        (widget.points ?? widget.history.fold<int>(0, (sum, h) => sum + h.score)) +
            _bonusByMonth.values.fold<int>(0, (a, b) => a + b);

    return SectionCard(
      title: AppStrings.attendanceSummary,
      icon: Icons.fact_check_rounded,
      accent: AppColors.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Overview(
            totals: totals,
            points: points,
            lastActivity: widget.lastActivity,
            months: _months,
            today: widget.today ?? DateTime.now(),
          ),
          if (_months.isNotEmpty) ...[
            const SizedBox(height: 12),
            _HistoryHeader(
              count: totals.held,
              open: _historyOpen,
              onTap: () => setState(() => _historyOpen = !_historyOpen),
            ),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _months.isEmpty || !_historyOpen
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _history(totals),
                  ),
          ),
        ],
      ),
    );
  }

  /// The sub-list: الكل / حضر / غاب, then the months.
  List<Widget> _history(LogTotals totals) {
    return [
      const SizedBox(height: 8),
      if (totals.held > 0) ...[
        Row(
          children: [
            for (final f in LogFilter.values) ...[
              if (f != LogFilter.all) const SizedBox(width: 6),
              Expanded(
                child: _FilterChip(
                  key: ValueKey('log-filter-${f.name}'),
                  label: switch (f) {
                    LogFilter.all => AppStrings.all,
                    LogFilter.present => AppStrings.logPresent,
                    LogFilter.absent => AppStrings.logAbsent,
                  },
                  count: switch (f) {
                    LogFilter.all => totals.held,
                    LogFilter.present => totals.attended,
                    LogFilter.absent => totals.held - totals.attended,
                  },
                  selected: _filter == f,
                  color: switch (f) {
                    LogFilter.all => AppColors.navy,
                    LogFilter.present => AppColors.success,
                    LogFilter.absent => AppColors.danger,
                  },
                  onTap: () => setState(() => _filter = f),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
      ],
      ..._monthsShown(),
    ];
  }

  List<Widget> _monthsShown() {
    final filtering = _filter != LogFilter.all;
    final out = <Widget>[];
    final bonusByMonth = _bonusByMonth;
    for (final m in _months) {
      // "الكل" also lists the no-lesson Saturdays; حضر / غاب only real ones.
      final rows = filtering
          ? m.recorded.where(_matches).toList()
          : m.listed;
      // While filtering, a month with nothing to show is left out and the
      // others open, so the matches are on screen at once.
      if (filtering && rows.isEmpty) continue;
      final open = rows.isNotEmpty && (filtering || _isOpen(m));
      out.add(_MonthSection(
        month: m,
        bonus: bonusByMonth[DateTime(m.month.year, m.month.month)] ?? 0,
        rows: rows,
        open: open,
        onToggle: filtering || rows.isEmpty
            ? null
            : () => setState(() => _open[m.month] = !open),
      ));
    }
    if (out.isEmpty && filtering) {
      out.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          AppStrings.logNoMatch,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      ));
    }
    return out;
  }
}

/// «سجل الحضور ▾  8 سبوت»: folds the month list under the summary.
class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navy.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey('log-history-toggle'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.history_rounded,
                    size: 18, color: AppColors.navy),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    AppStrings.attendanceHistory,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                if (count > 0)
                  Text(
                    AppStrings.logSaturdays(count),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The year at a glance: average with its bar, Saturdays and points, then
/// the four activities with their count and the last time each was done.
class _Overview extends StatelessWidget {
  const _Overview({
    required this.totals,
    required this.points,
    required this.lastActivity,
    required this.months,
    required this.today,
  });

  final LogTotals totals;
  final int points;
  final ChildLastActivity? lastActivity;
  final List<LogMonth> months;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final held = totals.held;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (held == 0)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              AppStrings.noAttendanceYet,
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else ...[
          PercentageBar(
            percentage: (totals.ratio ?? 0) * 100,
            label: AppStrings.averageAttendance,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: AppStrings.attendedSessions,
                  value: '${totals.attended}/$held',
                  color: AppColors.navy,
                  icon: Icons.event_available_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: AppStrings.totalPoints,
                  value: '$points',
                  color: AppColors.olive,
                  icon: Icons.star_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // Two by two: each activity, how often, and when last.
        for (final pair in const [
          [LogActivity.sundaySchool, LogActivity.vespers],
          [LogActivity.mass, LogActivity.confession],
        ]) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in pair) ...[
                if (a != pair.first) const SizedBox(width: 8),
                Expanded(
                  child: _ActivityTile(
                    activity: a,
                    count: totals.perActivity[a] ?? 0,
                    held: held,
                    last: a.lastDone(
                      months,
                      lastActivity == null ? null : a.lastIn(lastActivity!),
                      today,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (pair.first == LogActivity.sundaySchool) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.activity,
    required this.count,
    required this.held,
    required this.last,
  });

  final LogActivity activity;
  final int count;
  final int held;
  final DateTime? last;

  @override
  Widget build(BuildContext context) {
    final color = activity.color;
    final pct = held == 0 ? null : (count / held * 100).round();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(activity.icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activity.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (held > 0)
                Text(
                  '$count/$held',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.readable(color),
                  ),
                ),
            ],
          ),
          if (pct != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: count / held,
                minHeight: 4,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            last == null
                ? AppStrings.neverAttended
                : AppStrings.logLastTime(AppDateUtils.sinceLabel(last!)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// "الكل 7" / "حضر 3" / "غاب 4".
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label $count',
      excludeSemantics: true,
      child: Material(
        color: selected ? statusTint(color) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? color.withValues(alpha: 0.5)
                : AppColors.muted.withValues(alpha: 0.25),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : AppColors.muted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : AppColors.muted,
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

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.month,
    required this.rows,
    required this.open,
    required this.onToggle,
    this.bonus = 0,
  });

  final LogMonth month;

  /// What the badges earned this month added to the month's طايو.
  final int bonus;
  final List<LogSaturday> rows;
  final bool open;

  /// Null while filtering, or when the month has nothing to list.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final ratio = month.ratio;
    final color = ratio == null
        ? AppColors.muted
        : ratio >= 0.75
            ? AppColors.success
            : ratio >= 0.5
                ? AppColors.warning
                : AppColors.danger;
    final sub = [
      if (month.held > 0) AppStrings.logPoints(month.points + bonus),
      if (month.notRecorded > 0) AppStrings.logUnrecorded(month.notRecorded),
      if (month.noLesson > 0) AppStrings.logNoLessonCount(month.noLesson),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 12),
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppDateUtils.formatMonth(month.month),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (month.held > 0)
                      Text(
                        AppStrings.logAttendedOf(month.attended, month.held),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.readable(color),
                        ),
                      ),
                    if (onToggle != null)
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_more,
                            color: AppColors.muted),
                      ),
                  ],
                ),
                if (month.held > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio ?? 0,
                      minHeight: 5,
                      color: color,
                      backgroundColor: AppColors.muted.withValues(alpha: 0.12),
                    ),
                  ),
                ],
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final s in rows) _SaturdayRow(s)],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// "7 نوفمبر   [4 icons]   20/20", or a غاب tag.
class _SaturdayRow extends StatelessWidget {
  const _SaturdayRow(this.day);

  final LogSaturday day;

  @override
  Widget build(BuildContext context) {
    final date = '${day.date.day} ${AppDateUtils.monthName(day.date.month)}';
    if (day.isBreak) {
      return Semantics(
        label: '${AppDateUtils.formatDayDate(day.date)}: '
            '${AppStrings.logNoLesson}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              SizedBox(
                width: 82,
                child: Text(
                  date,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _Tag(
                    text: AppStrings.logNoLesson,
                    color: AppColors.olive,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final score = day.score!;
    final status = score.isPresent
        ? [
            for (final a in LogActivity.values)
              if (a.on(score)) a.label,
          ].join('، ')
        : AppStrings.logAbsent;

    return Semantics(
      label: '${AppDateUtils.formatDayDate(day.date)}: $status',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 82,
              child: Text(
                date,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: !score.isPresent
                  ? const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _Tag(
                        text: AppStrings.logAbsent,
                        color: AppColors.danger,
                      ),
                    )
                  : Row(
                      children: [
                        for (final a in LogActivity.values)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: _ActivityDot(
                              activity: a,
                              done: a.on(score),
                            ),
                          ),
                      ],
                    ),
            ),
            if (score.isPresent)
              ScoreChip(
                score: score.score,
                maxScore: score.maxScore,
                compact: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityDot extends StatelessWidget {
  const _ActivityDot({required this.activity, required this.done});

  final LogActivity activity;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = activity.color;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? color.withValues(alpha: 0.16) : Colors.transparent,
        border: Border.all(
          color: done
              ? color.withValues(alpha: 0.5)
              : AppColors.muted.withValues(alpha: 0.2),
        ),
      ),
      child: Icon(
        activity.icon,
        size: 15,
        color: done ? color : AppColors.muted.withValues(alpha: 0.35),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statusTint(color, 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.readable(color),
        ),
      ),
    );
  }
}
