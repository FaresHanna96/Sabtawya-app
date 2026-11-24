import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/arabic_sort.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/class_filter_chips.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/profile.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../data/services/excel_service.dart';
import '../../data/supabase/db.dart';
import '../../data/services/file_service.dart';
import '../../state/session_controller.dart';
import 'prep_review_sheet.dart';
import 'preps_inbox_screen.dart';
import 'servant_activity_detail_screen.dart';
import 'servant_marks.dart';
import 'servant_day_widgets.dart';
import 'servant_covers.dart';
import 'servant_year.dart';
import '../attendance/attendance_swipe.dart';

/// Admin overview of all servants' activity stats.
///
/// [showAppBar] is false when the screen sits inside the home shell, which
/// already has its own title bar; the tabs and the report button then sit in a
/// strip under it instead of a second title bar.
class AdminServantActivitiesScreen extends StatelessWidget {
  const AdminServantActivitiesScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  /// Asks yearly or this month, then shares the matching Excel report (the
  /// same files as the export screen).
  Future<void> _export(BuildContext context) async {
    final monthly = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                AppStrings.exportEvent,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text(AppStrings.exportServantYearly),
              onTap: () => Navigator.of(sheet).pop(false),
            ),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: Text(
                '${AppStrings.exportServantMonthly} '
                '(${AppDateUtils.formatMonth(DateTime.now())})',
              ),
              onTap: () => Navigator.of(sheet).pop(true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (monthly == null || !context.mounted) return;

    const repo = ServantActivityRepository();
    final year = context.read<SessionController>().currentYear;
    final yearId = year?.id;
    final name = monthly
        ? AppStrings.exportServantMonthly
        : AppStrings.exportServantYearly;
    List<int>? bytes;
    final ok = await Ui.runGuarded(context, () async {
      if (monthly) {
        final now = DateTime.now();
        final data =
            await repo.servantMonthlyReport(year: now.year, month: now.month);
        if (data.isNotEmpty) {
          bytes = ExcelService.servantMonthlyWorkbook(
            data: data,
            monthLabel: AppDateUtils.formatMonth(now),
          );
        }
      } else {
        final summaries = await repo.activitySummaries(
          from: year?.startDate,
          to: year?.endDate,
        );
        final total =
            yearId == null ? 0 : await repo.sessionCountForYear(yearId);
        if (summaries.isNotEmpty) {
          bytes = ExcelService.servantYearlyWorkbook(
            summaries: summaries,
            totalSessions: total,
          );
        }
      }
    });
    if (!ok || !context.mounted) return;
    if (bytes == null) {
      Ui.info(context, AppStrings.noData);
      return;
    }
    try {
      await FileService.saveAndShare(
        fileName: FileService.xlsxName(name),
        bytes: bytes!,
      );
      if (context.mounted) Ui.success(context, AppStrings.exportDone);
    } catch (e) {
      if (context.mounted) Ui.error(context, e);
    }
  }

  static const _tabBar = TabBar(
    tabs: [
      Tab(text: AppStrings.servantsTab),
      Tab(text: AppStrings.servantAttendanceTab),
    ],
    indicatorColor: Colors.white,
    labelColor: Colors.white,
    unselectedLabelColor: Colors.white60,
  );

  @override
  Widget build(BuildContext context) {
    const body = TabBarView(
      children: [
        _SummaryTab(),
        _AttendanceTab(),
      ],
    );

    return DefaultTabController(
      length: 2,
      child: showAppBar
          ? Scaffold(
              appBar: AppBar(
                title: const Text(AppStrings.servantActivities),
                actions: [
                  IconButton(
                    tooltip: AppStrings.exportEvent,
                    icon: const Icon(Icons.ios_share),
                    onPressed: () => _export(context),
                  ),
                ],
                bottom: _tabBar,
              ),
              body: const SafeArea(child: body),
            )
          : Column(
              children: [
                Material(
                  color: Theme.of(context).appBarTheme.backgroundColor ??
                      Theme.of(context).colorScheme.primary,
                  child: Row(
                    children: [
                      const Expanded(child: _tabBar),
                      IconButton(
                        tooltip: AppStrings.exportEvent,
                        color: Colors.white,
                        icon: const Icon(Icons.ios_share),
                        onPressed: () => _export(context),
                      ),
                    ],
                  ),
                ),
                const Expanded(child: body),
              ],
            ),
    );
  }
}

// ============================================================= Tab 1: summary

class _SummaryTab extends StatefulWidget {
  const _SummaryTab();

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab>
    with AutomaticKeepAliveClientMixin {
  static const _repo = ServantActivityRepository();
  final _key = GlobalKey<AsyncSectionState<_ScreenData>>();

  @override
  bool get wantKeepAlive => true;

  /// Typed into the search box above the servants.
  String _query = '';

  ServantSort _sort = ServantSort.name;

  Future<_ScreenData> _load() async {
    final year = context.read<SessionController>().currentYear;
    final yearId = year?.id;
    final today = DateTime.now();
    final results = await Future.wait([
      // This year's counts, to match the base (this year's Saturdays).
      _repo.activitySummaries(from: year?.startDate, to: year?.endDate),
      yearId != null ? _repo.sessionCountForYear(yearId) : Future.value(0),
    ]);
    final summaries = results[0] as List<ServantActivitySummary>;
    // The follow-up card and the trends: best effort, the list stands
    // without them.
    ServantYear? servantYear;
    // The نشاط ترفيهي Saturdays held so far: counted for attendance, but no
    // prep is expected on them.
    var activityHeld = 0;
    var people = const <String, Profile>{};
    var classOf = const <String, String>{};
    if (year != null && yearId != null) {
      try {
        final extra = await Future.wait([
          _repo.sessionDatesForYear(yearId),
          _repo.attendancesBetween(from: year.startDate, to: today),
          _repo.recentPreps(limit: 1000),
          const ServantRepository().servants(includeInactive: false),
          const ClassRepository().allAssignments(),
          _repo
              .activityDatesForYear(yearId)
              .catchError((Object _) => const <DateTime>[]),
        ]);
        activityHeld = (extra[5] as List<DateTime>)
            .where((d) => !d.isAfter(today))
            .length;
        servantYear = ServantYear(
          noPrepDays: extra[5] as List<DateTime>,
          heldSaturdays: extra[0] as List<DateTime>,
          marks: extra[1] as List<ServantAttendance>,
          preps: [
            for (final p in extra[2] as List<LessonPrep>)
              if (!p.sessionDate.isBefore(year.startDate)) p,
          ],
          today: today,
          classServantIds: {
            for (final s in summaries)
              if (s.classesCount > 0) s.servantId,
          },
        );
        people = {for (final p in extra[3] as List<Profile>) p.id: p};
        classOf = {
          for (final a in extra[4] as List<ClassServant>)
            a.servantId: a.className,
        };
      } catch (_) {
        servantYear = null;
      }
    }
    return _ScreenData(
      summaries: summaries,
      totalSessions: results[1] as int,
      activityHeld: activityHeld,
      year: servantYear,
      people: people,
      classOf: classOf,
    );
  }

  Future<void> _openDetail(ServantActivitySummary summary) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ServantActivityDetailScreen(
          servantId: summary.servantId,
          servantName: summary.servantName,
        ),
      ),
    );
    _key.currentState?.reload();
  }

  /// «قيد المراجعة» opens every prep in one list (التحضيرات).
  Future<void> _openPreps() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PrepsInboxScreen()),
    );
    _key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AsyncSection<_ScreenData>(
      key: _key,
      load: _load,
      builder: (context, data, _) {
        if (data.summaries.isEmpty) {
          return ListView(children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.06),
            const EmptyState(
              icon: Icons.volunteer_activism_outlined,
              title: AppStrings.noLessonPreps,
              body: AppStrings.noLessonPrepsBody,
            ),
          ]);
        }

        final totalPending =
            data.summaries.fold(0, (s, e) => s + e.pendingPreps);
        final shown = sortServants(
          [
            for (final s in data.summaries)
              if (_matches(s.servantName, _query)) s,
          ],
          _sort,
          held: data.totalSessions,
          prepHeld: data.prepSessions,
        );

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: shown.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(children: [
                FadeSlideIn(
                  child: _StatsHeader(
                    totalServants: data.summaries.length,
                    totalSessions: data.totalSessions,
                    totalPending: totalPending,
                    onPendingTap: _openPreps,
                  ),
                ),
                const SizedBox(height: 12),
                _SearchBox(onChanged: (q) => setState(() => _query = q)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in ServantSort.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text(s.label),
                            selected: _sort == s,
                            onSelected: (_) => setState(() => _sort = s),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ]);
            }
            final s = shown[index - 1];
            final card = Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ServantRow(
                summary: s,
                held: data.totalSessions,
                prepHeld: data.prepSessions,
                trend: data.year?.trend(s.servantId),
                onTap: () => _openDetail(s),
              ),
            );
            // Only the first screenful slides in.
            return index <= 12 ? FadeSlideIn(index: index, child: card) : card;
          },
        );
      },
    );
  }
}

// ========================================================= Tab 2: attendance

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab();

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab>
    with AutomaticKeepAliveClientMixin {
  static const _repo = ServantActivityRepository();
  static const _servantRepo = ServantRepository();

  bool _loading = true;
  String? _error;
  List<DateTime> _sessionDates = [];
  List<Profile> _servants = [];
  DateTime? _selectedDate;

  /// The نشاط ترفيهي Saturdays (yyyy-MM-dd): servants are marked as usual,
  /// the prep slot is greyed out.
  Set<String> _activityDays = const {};

  bool get _selectedIsActivity =>
      _selectedDate != null &&
      _activityDays.contains(AppDateUtils.toIsoDate(_selectedDate!));

  /// The marks of the Saturday shown; a tap flips one at once (see
  /// [ServantMarks]) and only that chip waits for the server.
  final _marks = ServantMarks();
  List<LessonPrep> _preps = [];

  /// Typed into the search box above the servants.
  String _query = '';

  /// The class each servant serves (servant id -> class name); a general
  /// servant has none.
  Map<String, String> _classOf = const {};

  /// Servant id -> the id of the class they serve.
  Map<String, String> _classIdOf = const {};

  /// The classes picked in the filter; empty is every servant.
  Set<String> _classFilter = const {};

  /// The Saturday whose «everyone marked» was already celebrated.
  DateTime? _celebrated;

  /// «مين غطّى؟» records on the selected Saturday.
  List<ServantSubstitute> _subs = const [];

  final _dateScrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dateScrollController.hasClients) return;
      final i = _selectedIndex;
      if (i <= 0) return;
      // Approximate chip width (label + padding) ~110px, gap 8px
      const chipW = 118.0;
      final offset = (i * chipW - 40).clamp(
        0.0,
        _dateScrollController.position.maxScrollExtent,
      );
      _dateScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  static DateTime _nearestDate(List<DateTime> dates) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    DateTime? best;
    int bestDiff = 999999;
    for (final d in dates) {
      final dOnly = DateTime(d.year, d.month, d.day);
      // Prefer past/today over future; among equals pick closest
      final diff = dOnly.difference(todayOnly).inDays.abs();
      final isPastOrToday = !dOnly.isAfter(todayOnly);
      if (best == null) {
        best = d;
        bestDiff = diff;
      } else {
        final bestOnly = DateTime(best.year, best.month, best.day);
        final bestIsPast = !bestOnly.isAfter(todayOnly);
        if (isPastOrToday && !bestIsPast) {
          best = d;
          bestDiff = diff;
        } else if (isPastOrToday == bestIsPast && diff < bestDiff) {
          best = d;
          bestDiff = diff;
        }
      }
    }
    return best ?? dates.last;
  }

  int get _selectedIndex {
    if (_selectedDate == null) return -1;
    final iso = AppDateUtils.toIsoDate(_selectedDate!);
    return _sessionDates.indexWhere((d) => AppDateUtils.toIsoDate(d) == iso);
  }

  List<Profile> get _shownServants {
    final order = {
      for (final (i, c) in context.read<SessionController>().myClasses.indexed)
        c.classId: i,
    };
    return orderServantsByClass(
      [
        for (final s in _servants)
          if (_matches(s.fullName, _query) &&
              (_classFilter.isEmpty || _classFilter.contains(_classIdOf[s.id])))
            s,
      ],
      classIdOf: _classIdOf,
      classOrder: order,
    );
  }

  /// Confetti once a Saturday has every servant shown marked.
  void _maybeCelebrate() {
    final date = _selectedDate;
    if (date == null || _celebrated == date || !mounted) return;
    final shown = _shownServants;
    final p = ServantDayProgress.of(
      servantIds: [for (final s in shown) s.id],
      isMarked: (id, type) => _find(id, type) != null,
      preps: _preps,
    );
    if (p.total > 0 && p.marked == p.total) {
      _celebrated = date;
      Celebration.show(context);
    }
  }

  /// All Saturdays in a sheet, newest first; tapping one selects it.
  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final date in _sessionDates)
              ListTile(
                leading: const Icon(Icons.event_outlined, size: 20),
                title: Text(AppDateUtils.formatDayDate(date)),
                trailing: _selectedDate != null &&
                        AppDateUtils.isSameDay(date, _selectedDate!)
                    ? const Icon(Icons.check, color: AppColors.success)
                    : null,
                onTap: () => Navigator.of(context).pop(date),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) await _selectDate(picked);
  }

  void _goPrev() {
    final i = _selectedIndex;
    if (i > 0) _selectDate(_sessionDates[i - 1]);
  }

  void _goNext() {
    final i = _selectedIndex;
    if (i >= 0 && i < _sessionDates.length - 1) {
      _selectDate(_sessionDates[i + 1]);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final yearId = context.read<SessionController>().currentYear?.id;
      final results = await Future.wait([
        yearId != null
            ? _repo.sessionDatesForYear(yearId)
            : Future.value(<DateTime>[]),
        _servantRepo.servants(includeInactive: false),
        // Which class each servant serves; without it the rows just say
        // nothing about the class.
        const ClassRepository()
            .allAssignments()
            .catchError((Object _) => const <ClassServant>[]),
        yearId != null
            ? _repo
                .activityDatesForYear(yearId)
                .catchError((Object _) => const <DateTime>[])
            : Future.value(<DateTime>[]),
      ]);
      final activity = {
        for (final d in results[3] as List<DateTime>) AppDateUtils.toIsoDate(d),
      };
      final dates = results[0] as List<DateTime>;
      final servants = results[1] as List<Profile>;
      final assignments = results[2] as List<ClassServant>;
      final classOf = {for (final a in assignments) a.servantId: a.className};
      final classIdOf = {for (final a in assignments) a.servantId: a.classId};
      // Default to the date closest to today (current week)
      final selected = dates.isNotEmpty ? _nearestDate(dates) : null;
      List<ServantAttendance> att = [];
      List<LessonPrep> preps = [];
      List<ServantSubstitute> subs = const [];
      if (selected != null) {
        final results = await Future.wait([
          _repo.servantAttendancesForDate(selected),
          _repo.allPrepsForDate(selected),
          _subsOn(selected),
        ]);
        att = results[0] as List<ServantAttendance>;
        preps = results[1] as List<LessonPrep>;
        subs = results[2] as List<ServantSubstitute>;
      }
      if (!mounted) return;
      setState(() {
        _sessionDates = dates;
        _activityDays = activity;
        _servants = servants;
        _classOf = classOf;
        _classIdOf = classIdOf;
        _selectedDate = selected;
        _marks.reset(att);
        _preps = preps;
        _subs = subs;
        _loading = false;
      });
      _scrollToSelectedDate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppFailure.from(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _selectDate(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _marks.reset(const []);
      _preps = [];
      _subs = const [];
      _loading = true;
    });
    try {
      final results = await Future.wait([
        _repo.servantAttendancesForDate(date),
        _repo.allPrepsForDate(date),
        _subsOn(date),
      ]);
      if (!mounted) return;
      // A later tap on another Saturday wins over this answer.
      if (_selectedDate != date) return;
      setState(() {
        _marks.reset(results[0] as List<ServantAttendance>);
        _preps = results[1] as List<LessonPrep>;
        _subs = results[2] as List<ServantSubstitute>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) Ui.error(context, e);
    }
  }

  /// Best effort: the page works without the substitutes table.
  Future<List<ServantSubstitute>> _subsOn(DateTime date) => _repo
      .substitutesOn(date)
      .catchError((Object _) => const <ServantSubstitute>[]);

  String _nameOf(String id) {
    for (final s in _servants) {
      if (s.id == id) return s.fullName;
    }
    return '';
  }

  /// Marks and substitutes again after a substitute is saved or undone.
  Future<void> _refreshDay(DateTime date) async {
    final results = await Future.wait([
      _repo.servantAttendancesForDate(date),
      _subsOn(date),
    ]);
    if (!mounted || _selectedDate != date) return;
    setState(() {
      _marks.reset(results[0] as List<ServantAttendance>);
      _subs = results[1] as List<ServantSubstitute>;
    });
  }

  /// «مين غطّى؟»: pick who covered [absent]'s class; they get «خدمة».
  Future<void> _pickSubstitute(Profile absent) async {
    final date = _selectedDate;
    final classId = _classIdOf[absent.id];
    if (date == null || classId == null) return;
    final candidates = orderServantsByClass(
      [
        for (final s in _servants)
          if (s.id != absent.id) s
      ],
      classIdOf: _classIdOf,
      classOrder: const {},
    );
    final picked = await showModalBottomSheet<Profile>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  AppStrings.pickSubstitute,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in candidates)
                      ListTile(
                        leading: const Icon(Icons.person_outline, size: 20),
                        title: Text(s.fullName),
                        subtitle: Text(
                          _classOf[s.id] ?? AppStrings.generalServantShort,
                        ),
                        onTap: () => Navigator.of(context).pop(s),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final ok = await Ui.runGuarded(
      context,
      () => _repo.recordSubstitute(
        date: date,
        classId: classId,
        absentServantId: absent.id,
        substituteServantId: picked.id,
      ),
      successMessage: AppStrings.substituteSaved,
    );
    if (ok) await _refreshDay(date);
  }

  Future<void> _removeSubstitute(ServantSubstitute sub) async {
    final date = _selectedDate;
    if (date == null) return;
    final ok = await Ui.runGuarded(
      context,
      () => _repo.removeSubstitute(sub.id),
    );
    if (ok) await _refreshDay(date);
  }

  /// Under a row: who covered them (with undo), whom they covered, or
  /// «مين غطّى؟» for a class servant with no «خدمة».
  Widget? _coverFooter(Profile servant) {
    final coveredBy = [
      for (final s in _subs)
        if (s.absentServantId == servant.id) s,
    ];
    final covering = [
      for (final s in _subs)
        if (s.substituteServantId == servant.id) s,
    ];
    final canAsk = coveredBy.isEmpty &&
        _classIdOf[servant.id] != null &&
        _find(servant.id, 'sunday_school') == null;
    if (coveredBy.isEmpty && covering.isEmpty && !canAsk) return null;
    return ServantCoverFooter(
      coveredBy: [
        for (final s in coveredBy)
          (
            name: _nameOf(s.substituteServantId),
            onRemove: () => _removeSubstitute(s)
          ),
      ],
      coveredFor: [for (final s in covering) _nameOf(s.absentServantId)],
      onAsk: canAsk ? () => _pickSubstitute(servant) : null,
    );
  }

  LessonPrep? _findPrep(String servantId) {
    for (final p in _preps) {
      if (p.servantId == servantId) return p;
    }
    return null;
  }

  Future<void> _reviewPrep(LessonPrep prep) async {
    await showPrepReviewSheet(
      context,
      prep: prep,
      onReview: (status, comment) async {
        await _repo.reviewPrep(
          prepId: prep.id,
          status: status,
          comment: comment,
        );
        if (_selectedDate != null) {
          final preps = await _repo.allPrepsForDate(_selectedDate!);
          if (mounted) setState(() => _preps = preps);
        }
      },
    );
  }

  ServantAttendance? _find(String servantId, String activityType) =>
      _marks.find(servantId, activityType);

  /// Shows the change at once, then saves it; a refusal puts it back with
  /// the error. Other chips stay usable meanwhile.
  Future<void> _toggle(String servantId, String activityType) async {
    final date = _selectedDate;
    if (date == null) return;
    MarkToggle? t;
    setState(() {
      t = _marks.begin(
        servantId: servantId,
        type: activityType,
        date: date,
        recordedBy: Db.userId ?? '',
      );
    });
    final toggle = t;
    if (toggle == null) return; // that chip is still saving
    try {
      ServantAttendance? saved;
      if (toggle.adding) {
        saved = await _repo.recordAttendance(
          servantId: servantId,
          activityType: activityType,
          date: date,
        );
      } else {
        await _repo.deleteAttendance(toggle.row.id);
      }
      if (!mounted || _selectedDate != date) return;
      setState(() => _marks.succeed(toggle, saved));
      if (toggle.adding) _maybeCelebrate();
    } catch (e) {
      if (!mounted) return;
      if (_selectedDate == date) setState(() => _marks.fail(toggle));
      Ui.error(context, e);
    }
  }

  /// The swipe on a servant: present at all four activities, or none.
  /// Each one that differs flips on its own (the prep is never touched).
  void _setAll(String servantId, bool present) {
    for (final type in servantDayActivities) {
      final marked = _find(servantId, type) != null;
      if (marked != present) _toggle(servantId, type);
    }
  }

  /// «الكل حضروا»: which activity, then everyone shown who has no mark in
  /// it yet gets one, in one request, on screen at once.
  Future<void> _markAll() async {
    final date = _selectedDate;
    if (date == null) return;
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                AppStrings.markAllWhich,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            for (final (t, icon, label) in const [
              ('sunday_school', AppIcons.sundaySchool, AppStrings.chipService),
              (
                'servant_meeting',
                AppIcons.servantMeeting,
                AppStrings.chipMeeting
              ),
              ('mass', AppIcons.mass, AppStrings.massShort),
              ('confession', AppIcons.confession, AppStrings.confessionShort),
            ])
              ListTile(
                leading: Icon(icon, color: AppColors.navy),
                title: Text(label),
                onTap: () => Navigator.of(sheet).pop(t),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;

    late final List<MarkToggle> toggles;
    setState(() {
      toggles = _marks.beginAll(
        servantIds: [for (final s in _shownServants) s.id],
        type: type,
        date: date,
        recordedBy: Db.userId ?? '',
      );
    });
    if (toggles.isEmpty) return;
    try {
      final saved = await _repo.recordAttendanceMany(
        servantIds: [for (final t in toggles) t.servantId],
        activityType: type,
        date: date,
      );
      if (!mounted || _selectedDate != date) return;
      final byServant = {for (final a in saved) a.servantId: a};
      setState(() {
        for (final t in toggles) {
          _marks.succeed(t, byServant[t.servantId]);
        }
      });
      _maybeCelebrate();
    } catch (e) {
      if (!mounted) return;
      if (_selectedDate == date) {
        setState(() {
          for (final t in toggles) {
            _marks.fail(t);
          }
        });
      }
      Ui.error(context, e);
    }
  }

  Future<void> _openDetail(Profile servant) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ServantActivityDetailScreen(
          servantId: servant.id,
          servantName: servant.fullName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading && _servants.isEmpty) return const SkeletonList();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    return Column(
      children: [
        // Saturday picker: arrows either side of the date, the date itself
        // opens the full list. Replaces a strip of chips that had to be
        // scrolled sideways.
        if (_sessionDates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: AppStrings.previousSaturday,
                  onPressed: _selectedIndex > 0 ? _goPrev : null,
                  icon: const Icon(AppIcons.back),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: AppColors.navy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickDate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.event_rounded,
                              size: 16,
                              color: AppColors.navy,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _selectedDate == null
                                    ? AppStrings.selectSaturday
                                    : AppDateUtils.formatDayDate(
                                        _selectedDate!,
                                      ),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: AppStrings.nextSaturday,
                  onPressed: _selectedIndex >= 0 &&
                          _selectedIndex < _sessionDates.length - 1
                      ? _goNext
                      : null,
                  icon: const Icon(AppIcons.forward),
                ),
              ],
            ),
          ),
        if (_selectedDate != null && _servants.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: ServantDayProgressLine(
              progress: ServantDayProgress.of(
                servantIds: [for (final s in _shownServants) s.id],
                isMarked: (id, type) => _find(id, type) != null,
                preps: _preps,
              ),
            ),
          ),
        if (_selectedIsActivity)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: ActivityDayBanner(),
          ),
        if (context.read<SessionController>().myClasses.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ClassFilterChips(
              classes: [
                for (final c in context.read<SessionController>().myClasses)
                  ClassFilterOption(id: c.classId, name: c.className),
              ],
              selectedIds: _classFilter,
              onChanged: (ids) => setState(() => _classFilter = ids),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ServantSearchRow(
            onChanged: (q) => setState(() => _query = q),
            onMarkAll:
                _selectedDate == null || _servants.isEmpty ? null : _markAll,
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
        // Servant list
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          // The list slides in when the Saturday changes (still with
          // "reduce motion").
          child: AnimatedSwitcher(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_selectedDate),
              child: _servants.isEmpty
                  ? ListView(children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.1),
                      const EmptyState(
                        icon: Icons.people_outline,
                        title: AppStrings.noServants,
                        body: AppStrings.noLessonPrepsBody,
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: _shownServants.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final servant = _shownServants[index];
                        final ss = _find(servant.id, 'sunday_school');
                        final sm = _find(servant.id, 'servant_meeting');
                        final mass = _find(servant.id, 'mass');
                        final conf = _find(servant.id, 'confession');
                        final prep = _findPrep(servant.id);
                        final lp = _find(servant.id, 'lesson_prep');
                        final look =
                            prepChipLook(prep, manualPresent: lp != null);
                        ServantSlot slot(String type, String label,
                                IconData icon, ServantAttendance? mark) =>
                            ServantSlot(
                              label: label,
                              icon: mark != null ? Icons.check_rounded : icon,
                              color: AppColors.success,
                              on: mark != null,
                              busy: _marks.isBusy(servant.id, type),
                              onTap: () => _toggle(servant.id, type),
                            );
                        return AttendanceSwipe(
                          id: '${_selectedDate?.toIso8601String()}-${servant.id}',
                          enabled: _selectedDate != null,
                          onAllPresent: () => _setAll(servant.id, true),
                          onClear: () => _setAll(servant.id, false),
                          onLongPress: () => _openDetail(servant),
                          child: ServantDayRow(
                            name: servant.fullName,
                            className: _classOf[servant.id],
                            footer: _coverFooter(servant),
                            onOpen: () => _openDetail(servant),
                            slots: [
                              ServantSlot(
                                label: AppStrings.chipPrep,
                                icon: look.icon,
                                color: look.color,
                                enabled: !_selectedIsActivity,
                                on: prep != null || lp != null,
                                busy: _marks.isBusy(servant.id, 'lesson_prep'),
                                semantics:
                                    '${AppStrings.chipPrep}: ${look.status}',
                                onTap: prep != null
                                    ? () => _reviewPrep(prep)
                                    : () => _toggle(servant.id, 'lesson_prep'),
                              ),
                              slot('sunday_school', AppStrings.chipService,
                                  AppIcons.sundaySchool, ss),
                              slot('servant_meeting', AppStrings.chipMeeting,
                                  AppIcons.servantMeeting, sm),
                              slot('mass', AppStrings.massShort, AppIcons.mass,
                                  mass),
                              slot('confession', AppStrings.confessionShort,
                                  AppIcons.confession, conf),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// How the تحضير chip looks: the prep's review status at a glance, so the
/// admin sees which ones still wait for them.
@visibleForTesting
({Color color, IconData icon, String status}) prepChipLook(
  LessonPrep? prep, {
  required bool manualPresent,
}) {
  if (prep != null) {
    // The same look as everywhere else a prep's status shows.
    return (
      color: prepStatusColor(prep.status),
      icon: prepStatusIcon(prep.status),
      status: prepStatusLabel(prep.status),
    );
  }
  if (manualPresent) {
    return (
      color: AppColors.success,
      icon: Icons.check_circle_outline,
      status: AppStrings.prepMarkedByHand,
    );
  }
  return (
    color: AppColors.muted,
    icon: Icons.assignment_outlined,
    status: AppStrings.prepNotSent,
  );
}

// ================================================================ shared data

class _ScreenData {
  const _ScreenData({
    required this.summaries,
    required this.totalSessions,
    this.activityHeld = 0,
    this.year,
    this.people = const {},
    this.classOf = const {},
  });
  final List<ServantActivitySummary> summaries;
  final int totalSessions;

  /// Saturdays held that were a نشاط ترفيهي (no prep expected).
  final int activityHeld;

  /// The Saturdays a class servant is expected to prepare for.
  int get prepSessions => totalSessions - activityHeld;

  /// The year's marks and preps (follow-up, trends); null when not loaded.
  final ServantYear? year;
  final Map<String, Profile> people;
  final Map<String, String> classOf;

  String nameOf(String servantId) {
    for (final s in summaries) {
      if (s.servantId == servantId) return s.servantName;
    }
    return people[servantId]?.fullName ?? '';
  }
}

// ================================================================ stats header

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({
    required this.totalServants,
    required this.totalSessions,
    required this.totalPending,
    this.onPendingTap,
  });

  final int totalServants;
  final int totalSessions;
  final int totalPending;
  final VoidCallback? onPendingTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _HeaderStat(
              icon: Icons.people_outline,
              value: '$totalServants',
              label: AppStrings.statServants),
          const _Divider(),
          _HeaderStat(
              icon: Icons.calendar_month_outlined,
              value: '$totalSessions',
              label: AppStrings.statSaturdays),
          const _Divider(),
          _HeaderStat(
            icon: Icons.hourglass_empty_outlined,
            value: '$totalPending',
            label: AppStrings.prepPending,
            accent: totalPending > 0 ? AppColors.warning : Colors.white70,
            onTap: onPendingTap,
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
    this.accent,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Colors.white;
    final stat = Column(
      children: [
        Icon(icon, size: 18, color: color.withValues(alpha: 0.85)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.readable(color))),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: AppColors.readable(color).withValues(alpha: 0.7))),
      ],
    );
    return Expanded(
      child: onTap == null
          ? stat
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: stat,
            ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 48,
        color: Colors.white.withValues(alpha: 0.2),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}

// ============================================================== servant card

/// How the servants are ordered on «الخدام».
enum ServantSort {
  name(AppStrings.sortServantName),
  lowest(AppStrings.sortServantLowest),
  leastPrep(AppStrings.sortServantLeastPrep),
  pending(AppStrings.sortServantPending);

  const ServantSort(this.label);

  final String label;
}

/// [list] in [sort] order; with [onlyPending], only those with a prep
/// waiting for review. "Lowest" is the average over the four activities of
/// [held] Saturdays; names break ties.
@visibleForTesting
List<ServantActivitySummary> sortServants(
  List<ServantActivitySummary> list,
  ServantSort sort, {
  required int held,
  int? prepHeld,
  bool onlyPending = false,
}) {
  final out = [
    for (final s in list)
      if (!onlyPending || s.pendingPreps > 0) s,
  ];
  int byName(ServantActivitySummary a, ServantActivitySummary b) =>
      ArabicSort.compare(a.servantName, b.servantName);
  out.sort(switch (sort) {
    ServantSort.name => byName,
    ServantSort.lowest => (a, b) {
        final c =
            (a.averageRate(held) ?? 0).compareTo(b.averageRate(held) ?? 0);
        return c != 0 ? c : byName(a, b);
      },
    // The fewest preps sent of those expected; a servant with no prep to
    // send (a خادم عام) goes last, as there is nothing to be short of.
    ServantSort.leastPrep => (a, b) {
        double? rate(ServantActivitySummary s) {
          final expected = s.expectedPreps(prepHeld ?? held);
          return expected == null || expected == 0
              ? null
              : s.totalPreps / expected;
        }

        final ra = rate(a), rb = rate(b);
        if (ra == null || rb == null) {
          if (ra != rb) return ra == null ? 1 : -1;
          return byName(a, b);
        }
        final c = ra.compareTo(rb);
        return c != 0 ? c : byName(a, b);
      },
    ServantSort.pending => (a, b) {
        final c = b.pendingPreps.compareTo(a.pendingPreps);
        return c != 0 ? c : byName(a, b);
      },
  });
  return out;
}

/// «حضور الخدام» order: by the order of their class, general servants (no
/// class) last; names within.
@visibleForTesting
List<Profile> orderServantsByClass(
  List<Profile> servants, {
  required Map<String, String> classIdOf,
  required Map<String, int> classOrder,
}) {
  int rank(Profile p) {
    final c = classIdOf[p.id];
    return c == null ? 1 << 20 : (classOrder[c] ?? (1 << 19));
  }

  return [...servants]..sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : ArabicSort.compare(a.fullName, b.fullName);
    });
}

/// One servant on one compact row: the name, the preps ("تحضير 5/8" and
/// what waits for review), and the four activities as percentages.
@visibleForTesting
class ServantRow extends StatelessWidget {
  const ServantRow({
    super.key,
    required this.summary,
    required this.held,
    this.prepHeld,
    required this.onTap,
    this.trend,
  });

  final ServantActivitySummary summary;

  /// Saturdays held so far this year.
  final int held;

  /// Of those, the ones a prep is expected for (no نشاط ترفيهي); [held] when
  /// not given.
  final int? prepHeld;
  final VoidCallback onTap;

  /// This month's attendance against last month's, in points; an arrow
  /// shows from ±10.
  final double? trend;

  @override
  Widget build(BuildContext context) {
    final expected = summary.expectedPreps(prepHeld ?? held);
    final prepColor = expected == null || expected == 0
        ? AppColors.navy
        : _level(summary.totalPreps / expected);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.servantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (trend != null && trend!.abs() >= 10)
                    TrendArrow(points: trend!),
                  _Pill(
                    text: expected == null
                        ? AppStrings.prepCount(summary.totalPreps)
                        : AppStrings.prepRate(summary.totalPreps, expected),
                    color: prepColor,
                    icon: Icons.assignment_outlined,
                  ),
                  if (summary.pendingPreps > 0) ...[
                    const SizedBox(width: 4),
                    _Pill(
                      text: '${summary.pendingPreps}',
                      color: AppColors.warning,
                      icon: Icons.hourglass_top_rounded,
                    ),
                  ],
                  const Icon(AppIcons.forward,
                      size: 18, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (icon, label, count) in [
                    (
                      AppIcons.sundaySchool,
                      AppStrings.chipService,
                      summary.sundaySchoolCount
                    ),
                    (
                      AppIcons.servantMeeting,
                      AppStrings.servantMeetingShort,
                      summary.servantMeetingCount
                    ),
                    (AppIcons.mass, AppStrings.massShort, summary.massCount),
                    (
                      AppIcons.confession,
                      AppStrings.confessionShort,
                      summary.confessionCount
                    ),
                  ])
                    Expanded(
                      child: Tooltip(
                        message: '$label: $count/$held',
                        child: Row(
                          children: [
                            Icon(icon,
                                size: 15,
                                color: held == 0
                                    ? AppColors.muted
                                    : _level(count / held)),
                            const SizedBox(width: 3),
                            Text(
                              held == 0
                                  ? '-'
                                  : '${(count / held * 100).round()}%',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: held == 0
                                    ? AppColors.muted
                                    : AppColors.readable(_level(count / held)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _level(double ratio) => ratio >= 0.75
      ? AppColors.success
      : ratio >= 0.5
          ? AppColors.warning
          : AppColors.danger;
}

/// ↑ / ↓ with the points, against last month.
@visibleForTesting
class TrendArrow extends StatelessWidget {
  const TrendArrow({super.key, required this.points});

  final double points;

  @override
  Widget build(BuildContext context) {
    final up = points > 0;
    final color = up ? AppColors.success : AppColors.danger;
    final n = points.abs().round();
    return Tooltip(
      message: up ? AppStrings.trendUp(n) : AppStrings.trendDown(n),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 2),
            Text(
              '$n',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.readable(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.readable(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Case- and space-insensitive "contains" for the servant search.
bool _matches(String name, String query) {
  final q = ArabicSort.key(query).replaceAll(' ', '');
  if (q.isEmpty) return true;
  return ArabicSort.key(name).replaceAll(' ', '').contains(q);
}

/// The search box and «الكل حضروا» on «حضور الخدام».
///
/// The button sets its own minimum size: the theme gives filled buttons
/// `Size.fromHeight(50)`, an infinite width meant for full-width buttons,
/// which a Row cannot lay out; the release build then drew this whole row
/// as an empty band.
@visibleForTesting
class ServantSearchRow extends StatelessWidget {
  const ServantSearchRow({
    super.key,
    required this.onChanged,
    required this.onMarkAll,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SearchBox(onChanged: onChanged)),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: onMarkAll,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text(AppStrings.allServantsCame),
        ),
      ],
    );
  }
}

/// Search field above the servant lists.
class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: AppStrings.searchServantHint,
        prefixIcon: Icon(Icons.search),
        isDense: true,
      ),
    );
  }
}
