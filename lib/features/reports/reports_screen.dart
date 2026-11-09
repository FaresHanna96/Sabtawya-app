import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
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

  String? _classId;

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

    return _latest = _ReportsData(
      children: await _reports.childYearReports(
        yearId: yearId,
        classId: _classId,
      ),
      classes: await _reports.classScores(yearId),
      monthly: await _reports.childMonthly(
        yearId: yearId,
        classId: _classId,
      ),
    );
  }

  Future<void> _reload() => _sectionKey.currentState?.reload() ?? Future.value();

  /// Exports the tab on screen with the class and period currently chosen.
  Future<void> _exportCurrent(int tab) async {
    final data = _latest;
    if (_exporting || data == null) return;

    final session = context.read<SessionController>();
    var scope = AppStrings.all;
    for (final item in session.myClasses) {
      if (item.classId == _classId) scope = item.className;
    }

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
        name = '${AppStrings.overallReport} - $scope';
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
                      ),
                    )
                    .toList(),
              );
        name = '${AppStrings.classReport} - $scope';
      default:
        final month = _monthShown(_monthsOf(data.monthly));
        final rows = month == null ? <ChildMonthlyReport>[] : _monthRows(data.monthly, month);
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
        ..sort((a, b) => b.points.compareTo(a.points));

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final classes = session.myClasses;
    final year = session.currentYear;

    return DefaultTabController(
      length: 3,
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
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (classes.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _classChip(null, AppStrings.all),
                        ...classes.map(
                          (item) => _classChip(item.classId, item.className),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: AsyncSection<_ReportsData>(
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
                                  visible: tabs.index != 2,
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
                                  onChanged: (g, from, to) => setState(() {
                                    _granularity = g;
                                    _filterFrom = from;
                                    _filterTo = to;
                                  }),
                                ),
                              );
                            },
                          ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _childrenTab(data),
                              _classesTab(data),
                              _monthlyTab(data.monthly, allDates),
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

  Widget _classChip(String? classId, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _classId == classId,
        onSelected: (_) {
          setState(() {
            _classId = classId;
            _granularity = null;
            _filterFrom = null;
            _filterTo = null;
          });
          _reload();
        },
      ),
    );
  }

  // ------------------------------------------------------------------ tabs

  List<_ChildScore> _childScores(_ReportsData data) {
    final List<_ChildScore> scores;

    if (_granularity == null) {
      // Build sessionsHeld per child from monthly data up to current month.
      final now = DateTime.now();
      final held = <String, int>{};
      for (final r in data.monthly) {
        if (r.monthStart.year < now.year ||
            (r.monthStart.year == now.year && r.monthStart.month <= now.month)) {
          held[r.childId] = (held[r.childId] ?? 0) + r.sessionsTotal;
        }
      }

      scores = data.children
          .map(
            (r) => _ChildScore(
              childId: r.childId,
              childName: r.childName,
              className: r.className,
              points: r.points,
              maxPoints: r.maxPoints,
              sessionsAttended: r.sessionsAttended,
              sessionsTotal: held[r.childId] ?? r.sessionsTotal,
            ),
          )
          .toList()
        ..sort((a, b) => b.points.compareTo(a.points));
    } else {
      scores = _aggregateChildren(data.monthly);
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: scores.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = scores[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ChildProfileScreen(childId: row.childId),
              ),
            ),
            leading: _RankBadge(rank: index + 1),
            title: Text(
              row.childName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${row.className} • '
              '${row.sessionsAttended}/${row.sessionsTotal} '
              '${AppStrings.attendedSessions}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: ScoreChip(
              score: row.points,
              maxScore: row.maxPoints,
              compact: true,
              showMax: false,
            ),
          ),
        );
      },
    );
  }

  List<_ClassScore> _classScores(_ReportsData data) {
    final List<_ClassScore> scores;

    if (_granularity == null) {
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
            ),
          )
          .toList()
        ..sort((a, b) {
          final ap = a.maxPoints > 0 ? a.points / a.maxPoints : 0.0;
          final bp = b.maxPoints > 0 ? b.points / b.maxPoints : 0.0;
          return bp.compareTo(ap);
        });
    } else {
      scores = _aggregateClasses(data.monthly);
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
                      percentage: row.maxPoints > 0
                          ? row.points / row.maxPoints * 100
                          : 0,
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
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = visible[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ChildProfileScreen(childId: row.childId),
                    ),
                  ),
                  leading: _RankBadge(rank: index + 1),
                  title: Text(
                    row.childName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${row.className} • '
                    '${row.sessionsAttended}/${row.sessionsTotal} '
                    '${AppStrings.attendedSessions}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: ScoreChip(
                    score: row.points,
                    maxScore: row.maxPoints,
                    compact: true,
                    showMax: false,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- aggregation

  bool _matchesFilter(DateTime date) {
    return DateGranularityFilter.matchesFilter(
      date: date,
      granularity: _granularity,
      from: _filterFrom,
      to: _filterTo,
    );
  }

  List<_ChildScore> _aggregateChildren(List<ChildMonthlyReport> monthly) {
    final points = <String, int>{};
    final maxPoints = <String, int>{};
    final attended = <String, int>{};
    final total = <String, int>{};
    final names = <String, String>{};
    final classes = <String, String>{};

    for (final row in monthly) {
      if (!_matchesFilter(row.monthStart)) continue;
      names[row.childId] = row.childName;
      classes[row.childId] = row.className;
      points[row.childId] = (points[row.childId] ?? 0) + row.points;
      maxPoints[row.childId] = (maxPoints[row.childId] ?? 0) + row.maxPoints;
      attended[row.childId] =
          (attended[row.childId] ?? 0) + row.sessionsAttended;
      total[row.childId] = (total[row.childId] ?? 0) + row.sessionsTotal;
    }

    return names.keys
        .map(
          (id) => _ChildScore(
            childId: id,
            childName: names[id]!,
            className: classes[id]!,
            points: points[id] ?? 0,
            maxPoints: maxPoints[id] ?? 0,
            sessionsAttended: attended[id] ?? 0,
            sessionsTotal: total[id] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.points.compareTo(a.points));
  }

  List<_ClassScore> _aggregateClasses(List<ChildMonthlyReport> monthly) {
    final points = <String, int>{};
    final maxPoints = <String, int>{};
    final childIds = <String, Set<String>>{};
    final names = <String, String>{};

    for (final row in monthly) {
      if (!_matchesFilter(row.monthStart)) continue;
      names[row.classId] = row.className;
      points[row.classId] = (points[row.classId] ?? 0) + row.points;
      maxPoints[row.classId] = (maxPoints[row.classId] ?? 0) + row.maxPoints;
      (childIds[row.classId] ??= <String>{}).add(row.childId);
    }

    return names.keys
        .map(
          (id) => _ClassScore(
            classId: id,
            className: names[id]!,
            children: childIds[id]?.length ?? 0,
            points: points[id] ?? 0,
            maxPoints: maxPoints[id] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) {
        final ap = a.maxPoints > 0 ? a.points / a.maxPoints : 0.0;
        final bp = b.maxPoints > 0 ? b.points / b.maxPoints : 0.0;
        return bp.compareTo(ap);
      });
  }
}

// ---------------------------------------------------------------- data models

class _ChildScore {
  const _ChildScore({
    required this.childId,
    required this.childName,
    required this.className,
    required this.points,
    required this.maxPoints,
    required this.sessionsAttended,
    required this.sessionsTotal,
  });

  final String childId;
  final String childName;
  final String className;
  final int points;
  final int maxPoints;
  final int sessionsAttended;
  final int sessionsTotal;
}

class _ClassScore {
  const _ClassScore({
    required this.classId,
    required this.className,
    required this.children,
    required this.points,
    required this.maxPoints,
  });

  final String classId;
  final String className;
  final int children;
  final int points;
  final int maxPoints;
}

class _ReportsData {
  const _ReportsData({
    required this.children,
    required this.classes,
    required this.monthly,
  });

  const _ReportsData.empty()
      : children = const <ChildYearReport>[],
        classes = const <ClassYearScore>[],
        monthly = const <ChildMonthlyReport>[];

  final List<ChildYearReport> children;
  final List<ClassYearScore> classes;
  final List<ChildMonthlyReport> monthly;
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
