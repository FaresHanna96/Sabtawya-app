import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/class_filter_chips.dart';
import '../../core/widgets/class_group_header.dart';
import '../../core/widgets/date_granularity_filter.dart';
import '../../data/models/reports.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/services/excel_service.dart';
import '../../data/services/file_service.dart';
import '../../state/session_controller.dart';
import '../children/child_profile_screen.dart';

/// Year standings, class standings, and the monthly breakdown.
///
/// Everything is read from the reporting views, which are `security_invoker`,
/// so a servant's report silently covers only their own classes.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _reports = ReportRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_ReportsData>>();

  /// The classes chosen; empty is all of them.
  Set<String> _classIds = <String>{};

  bool _inClasses(String classId) =>
      _classIds.isEmpty || _classIds.contains(classId);

  DateGranularity? _granularity;
  DateTime? _filterFrom;
  DateTime? _filterTo;

  /// The month chip tapped on the monthly tab.
  DateTime? _selectedMonth;

  /// The data the screen is showing, kept so the export button writes the same
  /// numbers the user sees.
  _ReportsData? _latest;
  bool _exporting = false;

  Future<_ReportsData> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return _latest = const _ReportsData.empty();

    final maxPerSession =
        context.read<SessionController>().currentYear?.maxPointsPerSession ??
            20;
    // One class: the database narrows it. Several: narrowed below.
    final oneClass = _classIds.length == 1 ? _classIds.first : null;
    // The three reads are independent, so run them side by side.
    final (children, classes, monthly, activity) = await (
      _reports.childYearReports(yearId: yearId, classId: oneClass),
      _reports.classScores(yearId),
      _reports.childMonthly(yearId: yearId, classId: oneClass),
      _reports.activityRates(yearId: yearId, classId: oneClass),
    ).wait;
    return _latest = _ReportsData(
      children: children.where((r) => _inClasses(r.classId)).toList(),
      classes: classes.where((r) => _inClasses(r.classId)).toList(),
      monthly: monthly.where((r) => _inClasses(r.classId)).toList(),
      activity: activity.where((r) => _inClasses(r.classId)).toList(),
      maxPerSession: maxPerSession,
    );
  }

  // ---- date range -------------------------------------------------------
  //
  // With a range chosen, only the Saturdays inside it are read (every class at
  // once, then narrowed to the chosen class here), and the list stays on
  // screen while they load. Changing the class never refetches them.

  /// Saturdays inside the chosen range; null when no range is set.
  List<SessionScore>? _sessions;
  bool _rangeLoading = false;
  int _rangeToken = 0;

  Future<void> _loadRange() async {
    final from = _filterFrom;
    final to = _filterTo;
    final token = ++_rangeToken;
    if (from == null && to == null) {
      setState(() {
        _sessions = null;
        _rangeLoading = false;
      });
      return;
    }
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return;
    setState(() => _rangeLoading = true);
    try {
      final rows = await _reports.sessionScores(
        yearId: yearId,
        from: from,
        to: to,
      );
      if (!mounted || token != _rangeToken) return; // a newer choice won
      setState(() {
        _sessions = rows;
        _rangeLoading = false;
      });
    } catch (e) {
      if (!mounted || token != _rangeToken) return;
      setState(() => _rangeLoading = false);
      Ui.error(context, e);
    }
  }

  /// The loaded Saturdays narrowed to the chosen class.
  List<SessionScore>? get _rangeRows =>
      _sessions?.where((r) => _inClasses(r.classId)).toList();

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  /// Exports the tab on screen with the class and period currently chosen.
  Future<void> _exportCurrent(int tab) async {
    final data = _latest;
    if (_exporting || data == null) return;
    if (_rangeLoading) {
      Ui.info(context, AppStrings.loading);
      return;
    }

    final session = context.read<SessionController>();
    final scope = _classIds.isEmpty
        ? AppStrings.all
        : ClassFilterChips.labelFor(
            [
              for (final c in session.myClasses)
                ClassFilterOption(id: c.classId, name: c.className),
            ],
            _classIds,
          );

    // " - 2026-10-03 إلى 2026-10-31" when a date range is chosen.
    String iso(DateTime d) => AppDateUtils.toIsoDate(d);
    final period = (_filterFrom == null && _filterTo == null)
        ? ''
        : ' - ${_filterFrom == null ? '' : iso(_filterFrom!)} '
            'إلى ${_filterTo == null ? '' : iso(_filterTo!)}';

    final List<int>? bytes;
    final String name;
    switch (tab) {
      case 0:
        final rows = _childScores(data);
        bytes = rows.isEmpty
            ? null
            : ExcelService.childScoresWorkbook(
                rows
                    .map(
                      (r) => ChildScoreRow(
                        className: r.className,
                        childName: r.childName,
                        attended: r.sessionsAttended,
                        total: r.sessionsTotal,
                        points: r.points,
                      ),
                    )
                    .toList(),
              );
        name = '${AppStrings.overallReport} - $scope$period';
      case 1:
        final rows = _classScores(data);
        bytes = rows.isEmpty
            ? null
            : ExcelService.classScoresWorkbook(
                rows
                    .map(
                      (r) => ClassScoreRow(
                        className: r.className,
                        children: r.children,
                        points: r.points,
                        maxPoints: r.maxPoints,
                        attended: r.attended,
                        held: r.held,
                      ),
                    )
                    .toList(),
              );
        name = '${AppStrings.classReport} - $scope$period';
      case 3:
        bytes = data.activity.isEmpty
            ? null
            : ExcelService.activityWorkbook(data.activity);
        name = '${AppStrings.activityReport} - $scope';
      default:
        final month = _monthShown(_monthsOf(data.monthly));
        final rows = month == null
            ? <ChildMonthlyReport>[]
            : _monthRows(data.monthly, month);
        bytes = rows.isEmpty ? null : ExcelService.monthlyWorkbook(rows);
        name = '${AppStrings.monthlyReport} - $scope'
            '${month == null ? '' : ' - ${AppDateUtils.formatMonth(month)}'}';
    }

    if (bytes == null) {
      Ui.info(context, AppStrings.noData);
      return;
    }

    setState(() => _exporting = true);
    try {
      await FileService.saveAndShare(
        fileName: FileService.timestampedName(name),
        bytes: bytes,
        shareText: name,
      );
      if (mounted) Ui.success(context, AppStrings.exportDone);
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<DateTime> _monthsOf(List<ChildMonthlyReport> monthly) =>
      monthly.map((r) => r.monthStart).toSet().toList()..sort();

  /// The month the monthly tab is showing: the chip the user tapped, else the
  /// latest month that has started.
  DateTime? _monthShown(List<DateTime> months) {
    if (months.isEmpty) return null;
    if (_selectedMonth != null) {
      for (final m in months) {
        if (AppDateUtils.isSameDay(m, _selectedMonth!)) return m;
      }
    }
    final now = DateTime.now();
    final started = months.where((m) => !m.isAfter(now)).toList();
    return started.isNotEmpty ? started.last : months.first;
  }

  List<ChildMonthlyReport> _monthRows(
    List<ChildMonthlyReport> monthly,
    DateTime month,
  ) =>
      monthly.where((r) => AppDateUtils.isSameDay(r.monthStart, month)).toList()
        ..sort((a, b) =>
            _byAttendance(a.percentage, a.points, b.percentage, b.points));

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final classes = session.myClasses;
    final year = session.currentYear;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.reportsTitle),
          actions: [
            // Exports the tab on screen (with the class and period chosen),
            // not the general export menu.
            Builder(
              builder: (context) => IconButton(
                tooltip: AppStrings.exportTitle,
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ios_share),
                onPressed: _exporting
                    ? null
                    : () => _exportCurrent(
                          DefaultTabController.of(context).index,
                        ),
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: AppStrings.overallReport),
              Tab(text: AppStrings.classReport),
              Tab(text: AppStrings.monthlyReport),
              Tab(text: AppStrings.activityReport),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (classes.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: ClassFilterChips(
                    classes: classes
                        .map((c) =>
                            ClassFilterOption(id: c.classId, name: c.className))
                        .toList(),
                    selectedIds: _classIds,
                    onChanged: (ids) {
                      // The period stays: class and period combine.
                      setState(() => _classIds = ids);
                      _reload();
                    },
                  ),
                ),
              Expanded(
                child: AsyncSection<_ReportsData>(
                  loading: const SkeletonList(),
                  key: _sectionKey,
                  load: _load,
                  builder: (context, data, reload) {
                    // All dates derived from monthly data for the picker.
                    final allDates = data.monthly
                        .map((r) => r.monthStart)
                        .toSet()
                        .toList()
                      ..sort();

                    return Column(
                      children: [
                        // The period picker narrows the general and class tabs.
                        // The monthly tab already has its month chips, so the
                        // picker is hidden there (kept alive, so its choice is
                        // not lost when switching tabs).
                        if (allDates.isNotEmpty)
                          Builder(
                            builder: (context) {
                              final tabs = DefaultTabController.of(context);
                              return AnimatedBuilder(
                                animation: tabs,
                                builder: (context, child) => Visibility(
                                  // Period picker: overall and class tabs
                                  // only (activity counts the whole year).
                                  visible: tabs.index < 2,
                                  maintainState: true,
                                  child: child!,
                                ),
                                child: DateGranularityFilter(
                                  availableDates: allDates,
                                  firstDate: year?.startDate,
                                  lastDate: year?.endDate,
                                  modes: const [
                                    DateGranularity.month,
                                    DateGranularity.year,
                                  ],
                                  initialGranularity: _granularity,
                                  onChanged: (g, from, to) {
                                    setState(() {
                                      _granularity = g;
                                      _filterFrom = from;
                                      _filterTo = to;
                                    });
                                    _loadRange();
                                  },
                                ),
                              );
                            },
                          ),
                        Expanded(
                          child: Stack(
                            children: [
                              TabBarView(
                                children: [
                                  _childrenTab(data),
                                  _classesTab(data),
                                  _monthlyTab(data.monthly, allDates),
                                  _activityTab(data.activity),
                                ],
                              ),
                              // While the Saturdays in the chosen range load:
                              // the branded loader over the (dimmed) list, so
                              // it is clear something is happening.
                              if (_rangeLoading)
                                Positioned.fill(
                                  child: ColoredBox(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    child: const Center(child: LoadingCard()),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ tabs

  List<_ChildScore> _childScores(_ReportsData data) {
    final List<_ChildScore> scores;

    if (_sessions == null) {
      // Build sessionsHeld per child from monthly data up to current month.
      final now = DateTime.now();
      final held = <String, int>{};
      for (final r in data.monthly) {
        if (r.monthStart.year < now.year ||
            (r.monthStart.year == now.year &&
                r.monthStart.month <= now.month)) {
          held[r.childId] = (held[r.childId] ?? 0) + r.sessionsTotal;
        }
      }

      scores = data.children
          .map(
            (r) => _ChildScore(
              childId: r.childId,
              childName: r.childName,
              classId: r.classId,
              className: r.className,
              points: r.points,
              maxPoints: r.maxPoints,
              sessionsAttended: r.sessionsAttended,
              sessionsTotal: held[r.childId] ?? r.sessionsTotal,
            ),
          )
          .toList()
        ..sort((a, b) =>
            _byAttendance(a.percentage, a.points, b.percentage, b.points));
    } else {
      scores = _aggregateChildren(data);
    }
    return scores;
  }

  Widget _childrenTab(_ReportsData data) {
    final scores = _childScores(data);

    if (scores.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events_outlined,
        title: AppStrings.noData,
      );
    }

    return _rankedList<_ChildScore>(
      rows: scores,
      classOf: (r) => r.classId,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      tile: (r, rank, showClass) => _scoreTile(
        childId: r.childId,
        childName: r.childName,
        className: showClass ? r.className : null,
        attended: r.sessionsAttended,
        total: r.sessionsTotal,
        points: r.points,
        maxPoints: r.maxPoints,
        rank: rank,
      ),
    );
  }

  List<_ClassScore> _classScores(_ReportsData data) {
    final List<_ClassScore> scores;

    if (_sessions == null) {
      // Correct max points to sessions held so far (months up to now).
      final now = DateTime.now();
      final classMaxHeld = <String, int>{};
      for (final r in data.monthly) {
        if (r.monthStart.year < now.year ||
            (r.monthStart.year == now.year &&
                r.monthStart.month <= now.month)) {
          classMaxHeld[r.classId] =
              (classMaxHeld[r.classId] ?? 0) + r.maxPoints;
        }
      }

      scores = data.classes
          .map(
            (r) => _ClassScore(
              classId: r.classId,
              className: r.className,
              children: r.children,
              points: r.points,
              maxPoints: classMaxHeld[r.classId] ?? r.maxPoints,
              attended: r.sessionsAttended,
              held: r.sessionsTotal,
            ),
          )
          .toList()
        ..sort((a, b) =>
            _byAttendance(a.percentage, a.points, b.percentage, b.points));
    } else {
      scores = _aggregateClasses(data);
    }
    return scores;
  }

  Widget _classesTab(_ReportsData data) {
    final scores = _classScores(data);

    if (scores.isEmpty) {
      return const EmptyState(
        icon: Icons.insert_chart_outlined,
        title: AppStrings.noData,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: scores
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PercentageBar(
                      percentage: row.percentage,
                      label: row.className,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${row.children} ${AppStrings.childrenTitle}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        ScoreChip(
                          score: row.points,
                          maxScore: row.maxPoints,
                          compact: true,
                          showMax: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _monthlyTab(
    List<ChildMonthlyReport> report,
    List<DateTime> allMonths,
  ) {
    // Month chips always list the whole year; the period picker only applies
    // to the other two tabs.
    final visibleMonths = allMonths;

    if (visibleMonths.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_view_month_outlined,
        title: AppStrings.noData,
      );
    }

    // The month the user tapped; otherwise the latest month that has started,
    // so the tab opens on "now" and not on a future month with no data.
    final selected = _monthShown(visibleMonths)!;
    final visible = _monthRows(report, selected);

    return Column(
      children: [
        if (visibleMonths.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: visibleMonths
                    .map(
                      (month) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(AppDateUtils.formatMonth(month)),
                          selected: AppDateUtils.isSameDay(month, selected),
                          onSelected: (_) =>
                              setState(() => _selectedMonth = month),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        Expanded(
          child: _rankedList<ChildMonthlyReport>(
            rows: visible,
            classOf: (r) => r.classId,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            tile: (r, rank, showClass) => _scoreTile(
              childId: r.childId,
              childName: r.childName,
              className: showClass ? r.className : null,
              attended: r.sessionsAttended,
              total: r.sessionsTotal,
              points: r.points,
              maxPoints: r.maxPoints,
              rank: rank,
            ),
          ),
        ),
      ],
    );
  }

  /// More than one class on screen: "كل الفصول" or several ticked.
  bool get _severalClasses {
    final mine = context.read<SessionController>().myClasses;
    return _classIds.length > 1 || (_classIds.isEmpty && mine.length > 1);
  }

  /// A ranking, best first. With several classes: a section per class, the
  /// rank restarting at 1 in each; otherwise one ranking for everyone.
  Widget _rankedList<T>({
    required List<T> rows,
    required String Function(T row) classOf,
    required Widget Function(T row, int rank, bool showClass) tile,
    required EdgeInsetsGeometry padding,
  }) {
    final classes = context.read<SessionController>().myClasses;
    final grouped = _severalClasses;
    return ClassGroupedList<T>(
      items: rows,
      grouped: grouped,
      classOf: classOf,
      classOrder: [for (final c in classes) c.classId],
      classNameOf: (id) {
        for (final c in classes) {
          if (c.classId == id) return c.className;
        }
        return '';
      },
      padding: padding,
      animate: false,
      // The header names the class, so the row does not repeat it.
      itemBuilder: (context, row, i) => tile(row, i + 1, !grouped),
    );
  }

  Widget _scoreTile({
    required String childId,
    required String childName,
    required String? className,
    required int attended,
    required int total,
    required int points,
    required int maxPoints,
    required int rank,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ChildProfileScreen(childId: childId),
          ),
        ),
        leading: _RankBadge(rank: rank),
        title: Text(
          childName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (className != null) className,
            '$attended/$total ${AppStrings.attendedSessions}',
          ].join(' • '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: ScoreChip(
          score: points,
          maxScore: maxPoints,
          compact: true,
          showMax: false,
        ),
      ),
    );
  }

  /// الأنشطة: per class, how often its children came to Sunday school,
  /// vespers, mass and confession (of the Saturdays held so far), then each
  /// child's four rates, grouped by class.
  Widget _activityTab(List<ChildActivityRate> rows) {
    if (rows.isEmpty) {
      return const EmptyState(
        icon: Icons.insert_chart_outlined,
        title: AppStrings.noData,
      );
    }
    final classes = context.read<SessionController>().myClasses;
    final byClass = <String, List<ChildActivityRate>>{};
    for (final r in rows) {
      (byClass[r.classId] ??= []).add(r);
    }
    final order = [
      for (final c in classes)
        if (byClass.containsKey(c.classId)) c.classId,
      for (final id in byClass.keys)
        if (!classes.any((c) => c.classId == id)) id,
    ];

    // The class's rate for one activity: attendances over (children x held).
    double classRate(List<ChildActivityRate> kids, int i) {
      final held = kids.fold<int>(0, (a, k) => a + k.held);
      final came = kids.fold<int>(0, (a, k) => a + k.counts[i]);
      return held > 0 ? came / held * 100 : 0;
    }

    final several = order.length > 1;
    return ClassGroupedList<ChildActivityRate>(
      items: rows,
      grouped: several,
      classOf: (r) => r.classId,
      classOrder: order,
      classNameOf: (id) => byClass[id]!.first.className,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      animate: false,
      leading: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SectionCard(
          title: AppStrings.activityByClass,
          icon: Icons.bar_chart_rounded,
          accent: AppColors.olive,
          child: Column(
            children: [
              for (final id in order)
                _ActivityClassRow(
                  name: byClass[id]!.first.className,
                  rates: [
                    for (var i = 0; i < 4; i++) classRate(byClass[id]!, i)
                  ],
                ),
            ],
          ),
        ),
      ),
      itemBuilder: (context, r, _) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ChildProfileScreen(childId: r.childId),
            ),
          ),
          title: Text(
            r.childName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _RateChip(
                      label: _activityLabels[i],
                      count: r.counts[i],
                      held: r.held,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- aggregation

  /// Children's standings over the Saturdays inside the chosen range.
  List<_ChildScore> _aggregateChildren(_ReportsData data) {
    final byChild = <String, List<SessionScore>>{};
    for (final r in _rangeRows ?? const <SessionScore>[]) {
      (byChild[r.childId] ??= []).add(r);
    }
    return byChild.entries.map((e) {
      final first = e.value.first;
      return _ChildScore(
        childId: e.key,
        childName: first.childName,
        classId: first.classId,
        className: first.className,
        points: e.value.fold<int>(0, (a, r) => a + r.score),
        maxPoints: e.value.length * data.maxPerSession,
        sessionsAttended: e.value.where((r) => r.present).length,
        sessionsTotal: e.value.length,
      );
    }).toList()
      ..sort((a, b) =>
          _byAttendance(a.percentage, a.points, b.percentage, b.points));
  }

  /// Classes' standings over the Saturdays inside the chosen range.
  List<_ClassScore> _aggregateClasses(_ReportsData data) {
    final byClass = <String, List<SessionScore>>{};
    for (final r in _rangeRows ?? const <SessionScore>[]) {
      (byClass[r.classId] ??= []).add(r);
    }
    return byClass.entries.map((e) {
      return _ClassScore(
        classId: e.key,
        className: e.value.first.className,
        children: e.value.map((r) => r.childId).toSet().length,
        points: e.value.fold<int>(0, (a, r) => a + r.score),
        maxPoints: e.value.length * data.maxPerSession,
        attended: e.value.where((r) => r.present).length,
        held: e.value.length,
      );
    }).toList()
      ..sort((a, b) =>
          _byAttendance(a.percentage, a.points, b.percentage, b.points));
  }
}

// ---------------------------------------------------------------- data models

class _ChildScore {
  const _ChildScore({
    required this.childId,
    required this.childName,
    required this.classId,
    required this.className,
    required this.points,
    required this.maxPoints,
    required this.sessionsAttended,
    required this.sessionsTotal,
  });

  final String childId;
  final String childName;
  final String classId;
  final String className;
  final int points;
  final int maxPoints;
  final int sessionsAttended;
  final int sessionsTotal;

  /// Attendance: Saturdays came over Saturdays held.
  double get percentage =>
      sessionsTotal > 0 ? sessionsAttended / sessionsTotal * 100 : 0;
}

class _ClassScore {
  const _ClassScore({
    required this.classId,
    required this.className,
    required this.children,
    required this.points,
    required this.maxPoints,
    required this.attended,
    required this.held,
  });

  final String classId;
  final String className;
  final int children;
  final int points;
  final int maxPoints;

  /// Saturdays came / held, summed over the class's children.
  final int attended;
  final int held;

  /// Attendance: Saturdays came over Saturdays held.
  double get percentage => held > 0 ? attended / held * 100 : 0;
}

/// Best attendance first, points breaking ties: the order every ranking in
/// the reports uses, so the rank matches the % shown.
int _byAttendance(double pa, int a, double pb, int b) {
  final byPct = pb.compareTo(pa);
  return byPct != 0 ? byPct : b.compareTo(a);
}

class _ReportsData {
  const _ReportsData({
    required this.children,
    required this.classes,
    required this.monthly,
    this.activity = const <ChildActivityRate>[],
    this.maxPerSession = 20,
  });

  const _ReportsData.empty()
      : children = const <ChildYearReport>[],
        classes = const <ClassYearScore>[],
        monthly = const <ChildMonthlyReport>[],
        activity = const <ChildActivityRate>[],
        maxPerSession = 20;

  final List<ChildYearReport> children;
  final List<ClassYearScore> classes;
  final List<ChildMonthlyReport> monthly;
  final List<ChildActivityRate> activity;

  final int maxPerSession;
}

// ---------------------------------------------------------------- rank badge

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  Color get _color => switch (rank) {
        1 => AppColors.warning,
        2 => AppColors.navyLight,
        3 => AppColors.olive,
        _ => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _color,
        ),
      ),
    );
  }
}

const _activityLabels = [
  AppStrings.sundaySchoolShort,
  AppStrings.vespersShort,
  AppStrings.massShort,
  AppStrings.confessionShort,
];

const _activityColors = [
  AppColors.navy,
  AppColors.sky,
  AppColors.olive,
  AppColors.maroon,
];

/// One class: four thin bars, one per activity, with the percentage.
class _ActivityClassRow extends StatelessWidget {
  const _ActivityClassRow({required this.name, required this.rates});

  final String name;
  final List<double> rates;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(
                      _activityLabels[i],
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (rates[i] / 100).clamp(0.0, 1.0),
                        minHeight: 7,
                        color: _activityColors[i],
                        backgroundColor:
                            _activityColors[i].withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${rates[i].round()}%',
                      textAlign: TextAlign.end,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _activityColors[i],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One child's activity: "قداس 3/7".
class _RateChip extends StatelessWidget {
  const _RateChip({
    required this.label,
    required this.count,
    required this.held,
  });

  final String label;
  final int count;
  final int held;

  @override
  Widget build(BuildContext context) {
    final rate = held > 0 ? count / held : 0.0;
    final color = rate >= 0.6
        ? AppColors.success
        : rate >= 0.3
            ? AppColors.warning
            : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          FittedBox(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          Text(
            '$count/$held',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
