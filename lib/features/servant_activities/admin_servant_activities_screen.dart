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
import '../../core/widgets/skeleton.dart';
import '../../data/models/profile.dart';
import '../../data/models/servant_activity.dart';
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
  bool _onlyPending = false;

  Future<_ScreenData> _load() async {
    final year = context.read<SessionController>().currentYear;
    final yearId = year?.id;
    final results = await Future.wait([
      // This year's counts, to match the base (this year's Saturdays).
      _repo.activitySummaries(from: year?.startDate, to: year?.endDate),
      yearId != null ? _repo.sessionCountForYear(yearId) : Future.value(0),
    ]);
    return _ScreenData(
      summaries: results[0] as List<ServantActivitySummary>,
      totalSessions: results[1] as int,
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
          onlyPending: _onlyPending,
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
                      FilterChip(
                        label: const Text(AppStrings.onlyPendingPreps),
                        selected: _onlyPending,
                        onSelected: (on) => setState(() => _onlyPending = on),
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

  /// The marks of the Saturday shown; a tap flips one at once (see
  /// [ServantMarks]) and only that chip waits for the server.
  final _marks = ServantMarks();
  List<LessonPrep> _preps = [];

  /// Typed into the search box above the servants.
  String _query = '';

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

  List<Profile> get _shownServants =>
      _servants.where((s) => _matches(s.fullName, _query)).toList();

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
      ]);
      final dates = results[0] as List<DateTime>;
      final servants = results[1] as List<Profile>;
      // Default to the date closest to today (current week)
      final selected = dates.isNotEmpty ? _nearestDate(dates) : null;
      List<ServantAttendance> att = [];
      List<LessonPrep> preps = [];
      if (selected != null) {
        final results = await Future.wait([
          _repo.servantAttendancesForDate(selected),
          _repo.allPrepsForDate(selected),
        ]);
        att = results[0] as List<ServantAttendance>;
        preps = results[1] as List<LessonPrep>;
      }
      if (!mounted) return;
      setState(() {
        _sessionDates = dates;
        _servants = servants;
        _selectedDate = selected;
        _marks.reset(att);
        _preps = preps;
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
      _loading = true;
    });
    try {
      final results = await Future.wait([
        _repo.servantAttendancesForDate(date),
        _repo.allPrepsForDate(date),
      ]);
      if (!mounted) return;
      // A later tap on another Saturday wins over this answer.
      if (_selectedDate != date) return;
      setState(() {
        _marks.reset(results[0] as List<ServantAttendance>);
        _preps = results[1] as List<LessonPrep>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) Ui.error(context, e);
    }
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
    } catch (e) {
      if (!mounted) return;
      if (_selectedDate == date) setState(() => _marks.fail(toggle));
      Ui.error(context, e);
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
          child: _servants.isEmpty
              ? ListView(children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
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
                    return _BulkServantRow(
                      servant: servant,
                      sundaySchoolPresent: ss != null,
                      servantMeetingPresent: sm != null,
                      massPresent: mass != null,
                      confessionPresent: conf != null,
                      prep: prep,
                      lessonPrepManual: lp != null,
                      busy: (type) => _marks.isBusy(servant.id, type),
                      onToggleSunday: () =>
                          _toggle(servant.id, 'sunday_school'),
                      onToggleMeeting: () =>
                          _toggle(servant.id, 'servant_meeting'),
                      onToggleMass: () => _toggle(servant.id, 'mass'),
                      onToggleConfession: () =>
                          _toggle(servant.id, 'confession'),
                      onPrep: prep != null
                          ? () => _reviewPrep(prep)
                          : () => _toggle(servant.id, 'lesson_prep'),
                      onDetail: () => _openDetail(servant),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _BulkServantRow extends StatelessWidget {
  const _BulkServantRow({
    required this.servant,
    required this.sundaySchoolPresent,
    required this.servantMeetingPresent,
    required this.massPresent,
    required this.confessionPresent,
    required this.prep,
    required this.lessonPrepManual,
    required this.busy,
    required this.onToggleSunday,
    required this.onToggleMeeting,
    required this.onToggleMass,
    required this.onToggleConfession,
    required this.onPrep,
    required this.onDetail,
  });

  final Profile servant;
  final bool sundaySchoolPresent;
  final bool servantMeetingPresent;
  final bool massPresent;
  final bool confessionPresent;
  final LessonPrep? prep;
  final bool lessonPrepManual;

  /// The chip of this activity type is being saved.
  final bool Function(String type) busy;
  final VoidCallback onToggleSunday;
  final VoidCallback onToggleMeeting;
  final VoidCallback onToggleMass;
  final VoidCallback onToggleConfession;
  final VoidCallback onPrep;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: avatar + name + arrow. Only this row opens the servant's
            // page, so a near miss on a chip below never navigates away.
            InkWell(
              onTap: onDetail,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline,
                          size: 16, color: AppColors.navy),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        servant.fullName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(AppIcons.forward,
                        size: 18, color: AppColors.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Row 2: chips, each a full-size touch target.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _PrepChip(
                    prep: prep,
                    manualPresent: lessonPrepManual,
                    disabled: busy('lesson_prep'),
                    onTap: onPrep),
                _Toggle(
                  label: AppStrings.chipService,
                  icon: AppIcons.sundaySchool,
                  present: sundaySchoolPresent,
                  disabled: busy('sunday_school'),
                  onTap: onToggleSunday,
                ),
                _Toggle(
                  label: AppStrings.chipMeeting,
                  icon: AppIcons.servantMeeting,
                  present: servantMeetingPresent,
                  disabled: busy('servant_meeting'),
                  onTap: onToggleMeeting,
                ),
                _Toggle(
                  label: AppStrings.massShort,
                  icon: AppIcons.mass,
                  present: massPresent,
                  disabled: busy('mass'),
                  onTap: onToggleMass,
                ),
                _Toggle(
                  label: AppStrings.confessionShort,
                  icon: AppIcons.confession,
                  present: confessionPresent,
                  disabled: busy('confession'),
                  onTap: onToggleConfession,
                ),
              ],
            ),
          ],
        ),
      ),
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

class _PrepChip extends StatelessWidget {
  const _PrepChip({
    required this.prep,
    required this.manualPresent,
    required this.disabled,
    required this.onTap,
  });

  final LessonPrep? prep;
  final bool manualPresent;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = prepChipLook(prep, manualPresent: manualPresent);
    final active = prep != null || manualPresent;
    final color = look.color;
    return Tooltip(
      message: look.status,
      child: Semantics(
        button: true,
        label: '${AppStrings.chipPrep}: ${look.status}',
        excludeSemantics: true,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: active ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: active ? 0.5 : 0.25),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(look.icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  AppStrings.chipPrep,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.readable(color),
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

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.icon,
    required this.present,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool present;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = present ? AppColors.success : AppColors.muted;
    return Semantics(
      button: true,
      toggled: present,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: present ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: color.withValues(alpha: present ? 0.5 : 0.25),
                width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                present ? Icons.check_circle : icon,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.readable(color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================ shared data

class _ScreenData {
  const _ScreenData({required this.summaries, required this.totalSessions});
  final List<ServantActivitySummary> summaries;
  final int totalSessions;
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
    ServantSort.pending => (a, b) {
        final c = b.pendingPreps.compareTo(a.pendingPreps);
        return c != 0 ? c : byName(a, b);
      },
  });
  return out;
}

/// One servant on one compact row: the name, the preps ("تحضير 5/8" and
/// what waits for review), and the four activities as percentages.
@visibleForTesting
class ServantRow extends StatelessWidget {
  const ServantRow({
    super.key,
    required this.summary,
    required this.held,
    required this.onTap,
  });

  final ServantActivitySummary summary;

  /// Saturdays held so far this year.
  final int held;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final expected = summary.expectedPreps(held);
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
                                    : _level(count / held),
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
