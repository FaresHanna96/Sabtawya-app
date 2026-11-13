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
        fileName: FileService.timestampedName(name),
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

  /// الحضور الشهري: load the year's months once, let the user pick one month
  /// (or كل الشهور), then export only that.
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
    final picked = await _pickMonth(months);
    if (picked == null || !mounted) return;
    final everyMonth = picked == _allMonths;

    await _export(
      name: '${AppStrings.exportMonthlyAttendance} - $_scopeLabel - '
          '${everyMonth ? AppStrings.allMonths : AppDateUtils.formatMonth(picked)}',
      build: () async {
        final rows = everyMonth
            ? all.where((r) => months.contains(_monthOf(r.monthStart))).toList()
            : all.where((r) => _monthOf(r.monthStart) == picked).toList();
        return rows.isEmpty ? null : ExcelService.monthlyWorkbook(rows);
      },
    );
  }

  /// Stands for "كل الشهور" in the month sheet.
  static final _allMonths = DateTime(0);

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  Future<DateTime?> _pickMonth(List<DateTime> months) {
    final current = _monthOf(DateTime.now());
    return showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                AppStrings.pickMonthToExport,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            for (final m in months)
              ListTile(
                leading: Icon(
                  Icons.calendar_month_outlined,
                  size: 20,
                  color: m == current ? AppColors.navy : AppColors.muted,
                ),
                title: Text(
                  AppDateUtils.formatMonth(m),
                  style: TextStyle(
                    fontWeight:
                        m == current ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                trailing: m == current
                    ? const Text(
                        AppStrings.thisMonth,
                        style: TextStyle(fontSize: 12, color: AppColors.navy),
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(m),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.date_range_outlined, size: 20),
              title: const Text(AppStrings.allMonths),
              onTap: () => Navigator.of(context).pop(_allMonths),
            ),
          ],
        ),
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
          final monthly = await _reports.childMonthly(yearId: yearId);
          final now = DateTime.now();
          final classMaxHeld = <String, int>{};
          for (final r in monthly) {
            if (r.monthStart.year < now.year ||
                (r.monthStart.year == now.year &&
                    r.monthStart.month <= now.month)) {
              classMaxHeld[r.classId] =
                  (classMaxHeld[r.classId] ?? 0) + r.maxPoints;
            }
          }
          return ExcelService.classReportWorkbook(
            scores,
            classMaxHeld: classMaxHeld.isEmpty ? null : classMaxHeld,
          );
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
