import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../data/models/attendance.dart';
import '../../data/models/reports.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../data/services/excel_service.dart';
import '../../data/services/file_service.dart';
import '../../state/session_controller.dart';

/// Builds the Excel files the spec asks for and hands them to the share sheet.
///
/// Every number written here comes from the database views, so an exported file
/// can never disagree with what the app shows.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();

  /// The months part of the file name: كل الشهور, one month, or the ticked
  /// months oldest first.
  static String monthsLabel(Set<DateTime> picked, List<DateTime> all) {
    if (picked.length == all.length) return AppStrings.allMonths;
    final sorted = picked.toList()..sort();
    return sorted.map(AppDateUtils.formatMonth).join('، ');
  }

  /// The months that had a Saturday held, up to [now], oldest first.
  static List<DateTime> monthsWithData(
    List<ChildMonthlyReport> rows,
    DateTime now,
  ) =>
      {
        for (final r in rows)
          if (r.sessionsTotal > 0 &&
              !DateTime(r.monthStart.year, r.monthStart.month).isAfter(now))
            DateTime(r.monthStart.year, r.monthStart.month),
      }.toList()
        ..sort();
}

class _ExportScreenState extends State<ExportScreen> {
  static const _children = ChildRepository();
  static const _attendance = AttendanceRepository();
  static const _reports = ReportRepository();
  static const _servantActivity = ServantActivityRepository();

  /// Null exports every class the caller can see.
  String? _classId;
  bool _busy = false;

  List<ClassOverview> get _classes =>
      context.read<SessionController>().myClasses;

  String _classNameOf(String classId) {
    for (final item in _classes) {
      if (item.classId == classId) return item.className;
    }
    return AppStrings.unknown;
  }

  String get _scopeLabel =>
      _classId == null ? AppStrings.all : _classNameOf(_classId!);

  /// Runs [build] then shares the workbook it produced.
  Future<void> _export({
    required String name,
    required Future<List<int>?> Function() build,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final bytes = await build();
      if (bytes == null) {
        if (mounted) Ui.info(context, AppStrings.noData);
        return;
      }
      await FileService.saveAndShare(
        fileName: FileService.xlsxName(name),
        bytes: bytes,
        shareText: name,
      );
      if (mounted) Ui.success(context, AppStrings.exportDone);
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? get _yearId => context.read<SessionController>().currentYear?.id;

  Future<void> _exportChildren() => _export(
        name: '${AppStrings.exportChildren} - $_scopeLabel',
        build: () async {
          final children = await _children.all(
            includeInactive: true,
            classId: _classId,
          );
          if (children.isEmpty) return null;
          return ExcelService.childrenWorkbook(
            children: children,
            classNameOf: _classNameOf,
          );
        },
      );

  Future<void> _exportAttendanceSheet() async {
    // كل الفصول: one file with every class that took attendance that day
    // (it used to fall back to the first class only).
    if (_classId == null && _classes.length > 1) {
      return _exportAllClassesSheet();
    }
    final classId =
        _classId ?? (_classes.isEmpty ? null : _classes.first.classId);
    final year = context.read<SessionController>().currentYear;
    if (classId == null || year == null) {
      Ui.info(context, AppStrings.selectClass);
      return;
    }

    final List<AttendanceSession> sessions;
    try {
      sessions = await _attendance.sessions(classId: classId, yearId: year.id);
    } catch (e) {
      if (mounted) Ui.error(context, e);
      return;
    }
    if (!mounted) return;
    if (sessions.isEmpty) {
      Ui.info(context, AppStrings.noSessionsTitle);
      return;
    }

    final session = await _pickSession(sessions);
    if (session == null || !mounted) return;

    await _export(
      name: '${AppStrings.exportAttendanceSheet} - ${_classNameOf(classId)} - '
          '${AppDateUtils.toIsoDate(session.sessionDate)}',
      build: () async {
        final sheet = await _attendance.sheet(session: session, year: year);
        if (sheet.entries.isEmpty) return null;
        return ExcelService.attendanceSheetWorkbook(
          className: _classNameOf(classId),
          sessionDate: session.sessionDate,
          entries: sheet.entries,
        );
      },
    );
  }

  /// كشف حضور سبت for every class: pick a Saturday, then one workbook
  /// grouped by class (a main sheet plus one sheet per class). Classes that
  /// did not take attendance that day are left out and named afterwards.
  Future<void> _exportAllClassesSheet() async {
    final year = context.read<SessionController>().currentYear;
    if (year == null || _busy) return;

    final List<AttendanceSession> sessions;
    try {
      sessions = await _attendance.sessionsForClasses(
        classIds: [for (final c in _classes) c.classId],
        yearId: year.id,
      );
    } catch (e) {
      if (mounted) Ui.error(context, e);
      return;
    }
    if (!mounted) return;
    if (sessions.isEmpty) {
      Ui.info(context, AppStrings.noSessionsTitle);
      return;
    }

    // One choice per Saturday, not one per class.
    final byDate = <DateTime, AttendanceSession>{
      for (final s in sessions) s.sessionDate: s,
    };
    final picked = await _pickSession(byDate.values.toList());
    if (picked == null || !mounted) return;
    final date = picked.sessionDate;
    final sameDay = sessions.where((s) => s.sessionDate == date).toList();

    var skipped = <String>[];
    await _export(
      name: '${AppStrings.exportAttendanceSheet} - ${AppStrings.all} - '
          '${AppDateUtils.toIsoDate(date)}',
      build: () async {
        final sheets = await _attendance.sheets(sessions: sameDay, year: year);
        final taken = [
          for (final s in sheets)
            if (s.entries.any((e) => e.isRecorded)) s,
        ];
        final takenIds = {for (final s in taken) s.session.classId};
        skipped = [
          for (final c in _classes)
            if (!takenIds.contains(c.classId)) c.className,
        ];
        if (taken.isEmpty) return null;
        return ExcelService.attendanceSheetsWorkbook(
          sessionDate: date,
          rows: [
            for (final s in taken)
              for (final e in s.entries)
                (className: _classNameOf(s.session.classId), entry: e),
          ],
        );
      },
    );
    if (skipped.isNotEmpty && mounted) {
      Ui.info(context, AppStrings.notRecordedClasses(skipped));
    }
  }

  Future<AttendanceSession?> _pickSession(
    List<AttendanceSession> sessions,
  ) async {
    final lastFirst = [...sessions]
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    return showModalBottomSheet<AttendanceSession>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: lastFirst.length,
          itemBuilder: (context, index) => staggered(
              index,
              ListTile(
                leading: const Icon(Icons.event_outlined, size: 20),
                title: Text(
                    AppDateUtils.formatDayDate(lastFirst[index].sessionDate)),
                onTap: () => Navigator.of(context).pop(lastFirst[index]),
              )),
        ),
      ),
    );
  }

  /// الحضور الشهري: load the year's months once, let the user tick one or
  /// more months (this month ticked to start), then export those.
  Future<void> _exportMonthly() async {
    final yearId = _yearId;
    if (yearId == null || _busy) return;
    setState(() => _busy = true);
    final List<ChildMonthlyReport> all;
    try {
      all = await _reports.childMonthly(yearId: yearId, classId: _classId);
    } catch (e) {
      if (mounted) Ui.error(context, e);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;

    final months = ExportScreen.monthsWithData(all, DateTime.now());
    if (months.isEmpty) {
      Ui.info(context, AppStrings.noData);
      return;
    }
    final picked = await _pickMonths(months);
    if (picked == null || picked.isEmpty || !mounted) return;

    await _export(
      name: '${AppStrings.exportMonthlyAttendance} - $_scopeLabel - '
          '${ExportScreen.monthsLabel(picked, months)}',
      build: () async {
        final rows =
            all.where((r) => picked.contains(_monthOf(r.monthStart))).toList();
        return rows.isEmpty ? null : ExcelService.monthlyWorkbook(rows);
      },
    );
  }

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  /// Tick the months to export; كل الشهور ticks or clears them all.
  Future<Set<DateTime>?> _pickMonths(List<DateTime> months) {
    final current = _monthOf(DateTime.now());
    final chosen = <DateTime>{
      if (months.contains(current)) current else months.last,
    };
    return showModalBottomSheet<Set<DateTime>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final everyMonth = chosen.length == months.length;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    AppStrings.pickMonthToExport,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                CheckboxListTile(
                  value: everyMonth,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    AppStrings.allMonths,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onChanged: (_) => setSheet(() {
                    if (everyMonth) {
                      chosen.clear();
                    } else {
                      chosen.addAll(months);
                    }
                  }),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final m in months)
                        CheckboxListTile(
                          value: chosen.contains(m),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            AppDateUtils.formatMonth(m),
                            style: TextStyle(
                              fontWeight: m == current
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                          secondary: m == current
                              ? const Text(
                                  AppStrings.thisMonth,
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.navy),
                                )
                              : null,
                          onChanged: (on) => setSheet(() {
                            if (on ?? false) {
                              chosen.add(m);
                            } else {
                              chosen.remove(m);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(chosen.isEmpty
                        ? AppStrings.pickMonths
                        : '${AppStrings.export} (${chosen.length})'),
                    onPressed: chosen.isEmpty
                        ? null
                        : () => Navigator.of(context).pop({...chosen}),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportYearly() => _export(
        name: '${AppStrings.exportYearlyAttendance} - $_scopeLabel',
        build: () async {
          final yearId = _yearId;
          if (yearId == null) return null;
          final report = await _reports.childYearReports(
            yearId: yearId,
            classId: _classId,
          );
          if (report.isEmpty) return null;
          final monthly = await _reports.childMonthly(
            yearId: yearId,
            classId: _classId,
          );
          final now = DateTime.now();
          final held = <String, int>{};
          for (final r in monthly) {
            if (r.monthStart.year < now.year ||
                (r.monthStart.year == now.year &&
                    r.monthStart.month <= now.month)) {
              held[r.childId] = (held[r.childId] ?? 0) + r.sessionsTotal;
            }
          }
          return ExcelService.yearlyWorkbook(
            report,
            sessionsHeldByChild: held.isEmpty ? null : held,
          );
        },
      );

  Future<void> _exportClassReport() => _export(
        name: AppStrings.exportClassReport,
        build: () async {
          final yearId = _yearId;
          if (yearId == null) return null;
          final scores = await _reports.classScores(yearId);
          if (scores.isEmpty) return null;
          // The view's % already counts only the Saturdays held so far.
          return ExcelService.classReportWorkbook(scores);
        },
      );

  Future<void> _exportTemplate() => _export(
        name: AppStrings.downloadTemplate,
        build: () async => ExcelService.childrenTemplate(),
      );

  Future<void> _exportServantMonthly() async {
    final now = DateTime.now();
    await _export(
      name: AppStrings.exportServantMonthly,
      build: () async {
        final data = await _servantActivity.servantMonthlyReport(
          year: now.year,
          month: now.month,
        );
        if (data.isEmpty) return null;
        return ExcelService.servantMonthlyWorkbook(
          data: data,
          monthLabel: AppDateUtils.formatMonth(now),
        );
      },
    );
  }

  Future<void> _exportServantYearly() async {
    final yearId = _yearId;
    if (yearId == null) {
      Ui.info(context, AppStrings.noData);
      return;
    }
    await _export(
      name: AppStrings.exportServantYearly,
      build: () async {
        final results = await Future.wait([
          _servantActivity.activitySummaries(),
          _servantActivity.sessionCountForYear(yearId),
        ]);
        final summaries = results[0] as List;
        final totalSessions = results[1] as int;
        if (summaries.isEmpty) return null;
        return ExcelService.servantYearlyWorkbook(
          summaries: summaries.cast(),
          totalSessions: totalSessions,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<SessionController>().myClasses;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.exportTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: staggerAll([
            if (_busy) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 12),
            ],
            if (classes.length > 1)
              SectionCard(
                title: AppStrings.classLabel,
                icon: Icons.class_rounded,
                accent: AppColors.olive,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text(AppStrings.all),
                      selected: _classId == null,
                      onSelected: (_) => setState(() => _classId = null),
                    ),
                    ...classes.map(
                      (item) => ChoiceChip(
                        label: Text(item.className),
                        selected: _classId == item.classId,
                        onSelected: (_) =>
                            setState(() => _classId = item.classId),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.exportTitle,
              icon: Icons.ios_share_rounded,
              accent: AppColors.navyLight,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Column(
                children: [
                  _ExportTile(
                    icon: Icons.groups_outlined,
                    title: AppStrings.exportChildren,
                    subtitle: _scopeLabel,
                    onTap: _busy ? null : _exportChildren,
                  ),
                  _ExportTile(
                    icon: Icons.fact_check_outlined,
                    title: AppStrings.exportAttendanceSheet,
                    subtitle: AppStrings.selectSaturday,
                    onTap: _busy ? null : _exportAttendanceSheet,
                  ),
                  _ExportTile(
                    icon: Icons.calendar_view_month_outlined,
                    title: AppStrings.exportMonthlyAttendance,
                    subtitle: _scopeLabel,
                    onTap: _busy ? null : _exportMonthly,
                  ),
                  _ExportTile(
                    icon: Icons.emoji_events_outlined,
                    title: AppStrings.exportYearlyAttendance,
                    subtitle: _scopeLabel,
                    onTap: _busy ? null : _exportYearly,
                  ),
                  _ExportTile(
                    icon: Icons.insert_chart_outlined,
                    title: AppStrings.exportClassReport,
                    subtitle: AppStrings.all,
                    onTap: _busy ? null : _exportClassReport,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (context.read<SessionController>().isAdmin)
              SectionCard(
                title: AppStrings.activitiesNav,
                icon: Icons.volunteer_activism_rounded,
                accent: AppColors.coral,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  children: [
                    _ExportTile(
                      icon: Icons.calendar_view_month_outlined,
                      title: AppStrings.exportServantMonthly,
                      subtitle: AppDateUtils.formatMonth(DateTime.now()),
                      onTap: _busy ? null : _exportServantMonthly,
                    ),
                    _ExportTile(
                      icon: Icons.emoji_events_outlined,
                      title: AppStrings.exportServantYearly,
                      subtitle: AppStrings.all,
                      onTap: _busy ? null : _exportServantYearly,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.importTitle,
              icon: Icons.upload_file_rounded,
              accent: AppColors.sky,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: _ExportTile(
                icon: Icons.download_outlined,
                title: AppStrings.downloadTemplate,
                subtitle: AppStrings.pickFileHint,
                onTap: _busy ? null : _exportTemplate,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: onTap != null,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.olive.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.olive, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.ios_share, size: 18, color: AppColors.muted),
    );
  }
}
