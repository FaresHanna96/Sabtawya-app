import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/profile.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../data/services/excel_service.dart';
import '../../data/services/file_service.dart';
import '../../state/session_controller.dart';
import 'prep_review_sheet.dart';
import 'servant_activities_report_screen.dart';
import 'servant_activity_detail_screen.dart';

/// Admin overview of all servants' activity stats.
///
/// [showAppBar] is false when the screen sits inside the home shell, which
/// already has its own title bar; the tabs and the report button then sit in a
/// strip under it instead of a second title bar.
class AdminServantActivitiesScreen extends StatelessWidget {
  const AdminServantActivitiesScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  void _openReport(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ServantActivitiesReportScreen(),
      ),
    );
  }

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
    final yearId = context.read<SessionController>().currentYear?.id;
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
        final summaries = await repo.activitySummaries();
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
        fileName: FileService.timestampedName(name),
        bytes: bytes!,
      );
      if (context.mounted) Ui.success(context, AppStrings.exportDone);
    } catch (e) {
      if (context.mounted) Ui.error(context, e);
    }
  }

  static const _tabBar = TabBar(
    tabs: [
      Tab(text: 'الخدام'),
      Tab(text: 'تسجيل الحضور'),
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
                  IconButton(
                    tooltip: AppStrings.servantActivityReport,
                    icon: const Icon(Icons.insert_chart_outlined),
                    onPressed: () => _openReport(context),
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
                      IconButton(
                        tooltip: AppStrings.servantActivityReport,
                        color: Colors.white,
                        icon: const Icon(Icons.insert_chart_outlined),
                        onPressed: () => _openReport(context),
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

  Future<_ScreenData> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    final results = await Future.wait([
      _repo.activitySummaries(),
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
        final shown = data.summaries
            .where((s) => _matches(s.servantName, _query))
            .toList();

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
                  ),
                ),
                const SizedBox(height: 12),
                _SearchBox(onChanged: (q) => setState(() => _query = q)),
                const SizedBox(height: 12),
              ]);
            }
            final s = shown[index - 1];
            final card = Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ServantCard(
                summary: s,
                totalSessions: data.totalSessions,
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
  List<ServantAttendance> _attendances = [];
  List<LessonPrep> _preps = [];
  bool _toggling = false;

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
            for (final date in _sessionDates.reversed)
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
        _attendances = att;
        _preps = preps;
        _loading = false;
      });
      _scrollToSelectedDate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectDate(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _attendances = [];
      _preps = [];
      _loading = true;
    });
    try {
      final results = await Future.wait([
        _repo.servantAttendancesForDate(date),
        _repo.allPrepsForDate(date),
      ]);
      if (!mounted) return;
      setState(() {
        _attendances = results[0] as List<ServantAttendance>;
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

  ServantAttendance? _find(String servantId, String activityType) {
    for (final a in _attendances) {
      if (a.servantId == servantId && a.activityType == activityType) return a;
    }
    return null;
  }

  Future<void> _toggle(
    String servantId,
    String activityType,
  ) async {
    if (_toggling || _selectedDate == null) return;
    final existing = _find(servantId, activityType);
    setState(() => _toggling = true);
    try {
      if (existing != null) {
        await _repo.deleteAttendance(existing.id);
        if (!mounted) return;
        setState(() => _attendances.removeWhere((a) => a.id == existing.id));
      } else {
        await _repo.recordAttendance(
          servantId: servantId,
          activityType: activityType,
          date: _selectedDate!,
        );
        // Reload to get the new ID
        final att = await _repo.servantAttendancesForDate(_selectedDate!);
        if (!mounted) return;
        setState(() => _attendances = att);
      }
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _toggling = false);
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

    if (_loading && _servants.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text(AppStrings.retry)),
          ],
        ),
      );
    }

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
                  onPressed: _selectedIndex > 0 ? _goPrev : null,
                  icon: const Icon(Icons.chevron_right),
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
                  onPressed: _selectedIndex >= 0 &&
                          _selectedIndex < _sessionDates.length - 1
                      ? _goNext
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SearchBox(onChanged: (q) => setState(() => _query = q)),
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
                      disabled: _toggling,
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
    required this.disabled,
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
  final bool disabled;
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
      child: InkWell(
        onTap: onDetail,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: avatar + name + arrow
              Row(
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
                  const Icon(Icons.chevron_left,
                      size: 18, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 8),
              // Row 2: chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _PrepChip(
                      prep: prep,
                      manualPresent: lessonPrepManual,
                      disabled: disabled,
                      onTap: onPrep),
                  _Toggle(
                    label: 'خدمة',
                    icon: Icons.church_outlined,
                    present: sundaySchoolPresent,
                    disabled: disabled,
                    onTap: onToggleSunday,
                  ),
                  _Toggle(
                    label: 'اجتماع',
                    icon: Icons.groups_outlined,
                    present: servantMeetingPresent,
                    disabled: disabled,
                    onTap: onToggleMeeting,
                  ),
                  _Toggle(
                    label: AppStrings.massShort,
                    icon: Icons.brightness_high_outlined,
                    present: massPresent,
                    disabled: disabled,
                    onTap: onToggleMass,
                  ),
                  _Toggle(
                    label: AppStrings.confessionShort,
                    icon: Icons.volunteer_activism_outlined,
                    present: confessionPresent,
                    disabled: disabled,
                    onTap: onToggleConfession,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    final hasSubmission = prep != null;
    final isActive = hasSubmission || manualPresent;
    final color = isActive ? AppColors.success : AppColors.muted;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isActive ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: isActive ? 0.5 : 0.25),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSubmission
                  ? Icons.check_circle
                  : isActive
                      ? Icons.check_circle_outline
                      : Icons.assignment_outlined,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              'تحضير',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
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
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: present ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: color.withValues(alpha: present ? 0.5 : 0.25), width: 1.2),
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
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
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
  });

  final int totalServants;
  final int totalSessions;
  final int totalPending;

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
              label: 'خادم'),
          const _Divider(),
          _HeaderStat(
              icon: Icons.calendar_month_outlined,
              value: '$totalSessions',
              label: 'جلسة'),
          const _Divider(),
          _HeaderStat(
            icon: Icons.hourglass_empty_outlined,
            value: '$totalPending',
            label: 'قيد المراجعة',
            accent: totalPending > 0 ? AppColors.warning : Colors.white70,
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
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Colors.white;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color.withValues(alpha: 0.85)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
        ],
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

class _ServantCard extends StatelessWidget {
  const _ServantCard({
    required this.summary,
    required this.totalSessions,
    required this.onTap,
  });

  final ServantActivitySummary summary;
  final int totalSessions;
  final VoidCallback onTap;

  double _pctValue(int count) =>
      totalSessions > 0 ? (count / totalSessions).clamp(0.0, 1.0) : 0.0;

  String _pctLabel(int count) =>
      totalSessions > 0 ? '${(count / totalSessions * 100).round()}%' : '-';

  @override
  Widget build(BuildContext context) {
    final hasPending = summary.pendingPreps > 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline,
                        size: 20, color: AppColors.navy),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      summary.servantName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (hasPending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${summary.pendingPreps} ${AppStrings.prepPending}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_left,
                      size: 18, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 12),
              _SmallChip(
                icon: Icons.assignment_outlined,
                label: AppStrings.lessonPrep,
                value: '${summary.totalPreps}',
                color: AppColors.navy,
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 10),
              _AttendanceBar(
                icon: Icons.church_outlined,
                label: AppStrings.sundaySchoolShort,
                count: summary.sundaySchoolCount,
                pctLabel: _pctLabel(summary.sundaySchoolCount),
                progress: _pctValue(summary.sundaySchoolCount),
                color: AppColors.success,
              ),
              const SizedBox(height: 8),
              _AttendanceBar(
                icon: Icons.groups_outlined,
                label: AppStrings.servantMeetingShort,
                count: summary.servantMeetingCount,
                pctLabel: _pctLabel(summary.servantMeetingCount),
                progress: _pctValue(summary.servantMeetingCount),
                color: AppColors.olive,
              ),
              const SizedBox(height: 8),
              _AttendanceBar(
                icon: Icons.brightness_high_outlined,
                label: AppStrings.massShort,
                count: summary.massCount,
                pctLabel: _pctLabel(summary.massCount),
                progress: _pctValue(summary.massCount),
                color: AppColors.navy,
              ),
              const SizedBox(height: 8),
              _AttendanceBar(
                icon: Icons.volunteer_activism_outlined,
                label: AppStrings.confessionShort,
                count: summary.confessionCount,
                pctLabel: _pctLabel(summary.confessionCount),
                progress: _pctValue(summary.confessionCount),
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceBar extends StatelessWidget {
  const _AttendanceBar({
    required this.icon,
    required this.label,
    required this.count,
    required this.pctLabel,
    required this.progress,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final String pctLabel;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
            const Spacer(),
            Text(
              '$count  ·  $pctLabel',
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Case- and space-insensitive "contains" for the servant search.
bool _matches(String name, String query) {
  final q = query.trim();
  if (q.isEmpty) return true;
  return name.replaceAll(' ', '').contains(q.replaceAll(' ', ''));
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
