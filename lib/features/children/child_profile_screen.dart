import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/attendance.dart';
import '../../data/models/child.dart';
import '../../data/models/reports.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';
import '../../state/session_controller.dart';
import 'child_avatar.dart';
import 'child_filters.dart';
import 'child_form_screen.dart';

/// Which attendance rows the history section shows.
enum _PresenceFilter {
  all(AppStrings.all),
  present(AppStrings.presentOnly),
  absent(AppStrings.absentOnly);

  const _PresenceFilter(this.label);

  final String label;
}

/// Everything known about one child: personal, parent, and church details plus
/// the attendance history and scores derived from them.
class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key, required this.childId});

  final String childId;

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  static const _children = ChildRepository();
  static const _attendance = AttendanceRepository();
  static const _reports = ReportRepository();
  static const _classes = ClassRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_ProfileData>>();

  /// Null means every month in the attendance year.
  DateTime? _monthFilter;
  _PresenceFilter _presenceFilter = _PresenceFilter.all;

  Future<_ProfileData> _load() async {
    // Read before the first await, while the context is certainly mounted.
    final yearId = context.read<SessionController>().currentYear?.id;

    final child = await _children.byId(widget.childId);
    if (child == null) {
      throw AppFailure('لم يتم العثور على المخدوم');
    }

    final classOverview = await _classes.overviewById(child.classId);

    return _ProfileData(
      child: child,
      className: classOverview?.className ?? AppStrings.unknown,
      yearReport: yearId == null
          ? null
          : await _reports.childYear(childId: child.id, yearId: yearId),
      monthly: yearId == null
          ? const <ChildMonthlyReport>[]
          : await _reports.childMonthly(
              yearId: yearId,
              childId: child.id,
              onlyActive: false,
            ),
      history: await _attendance.childHistory(
        childId: child.id,
        yearId: yearId,
      ),
      lastActivity: await _reports.lastActivity(child.id),
    );
  }

  Future<void> _reload() => _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _edit(Child child) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => ChildFormScreen(child: child)),
    );
    if (changed == true) await _reload();
  }

  Future<void> _toggleActive(Child child) async {
    if (child.isActive) {
      final confirmed = await Ui.confirm(
        context,
        title: AppStrings.deactivateChild,
        message: AppStrings.confirmDeactivateChild,
        confirmLabel: AppStrings.deactivateChild,
        destructive: true,
      );
      if (!confirmed) return;
    }

    if (!mounted) return;
    final ok = await Ui.runGuarded(
      context,
      () => _children.setActive(child.id, !child.isActive),
      successMessage: child.isActive
          ? AppStrings.childDeactivated
          : AppStrings.childActivated,
    );
    if (ok && mounted) {
      await context.read<SessionController>().refreshClasses();
      await _reload();
    }
  }

  Future<void> _move(Child child, String currentClassName) async {
    final classes = await _classes.list();
    if (!mounted) return;

    final target = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MoveChildSheet(
        classes: classes.where((item) => item.id != child.classId).toList(),
        currentClassName: currentClassName,
      ),
    );
    if (target == null || !mounted) return;

    final ok = await Ui.runGuarded(
      context,
      () => _children.moveToClass(childId: child.id, newClassId: target),
      successMessage: AppStrings.childMoved,
    );
    if (ok && mounted) {
      await context.read<SessionController>().refreshClasses();
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<SessionController>().isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.childProfile)),
      body: AsyncSection<_ProfileData>(
        key: _sectionKey,
        load: _load,
        builder: (context, data, reload) {
          final child = data.child;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(child, data.className),
              const SizedBox(height: 16),
              if (data.yearReport != null) ...[
                _summary(data.yearReport!, data.monthly),
                const SizedBox(height: 16),
              ],
              SectionCard(
                title: AppStrings.personalInfo,
                child: Column(
                  children: [
                    InfoRow(
                      label: AppStrings.childName,
                      value: child.fullName,
                      icon: Icons.person_outline,
                    ),
                    InfoRow(
                      label: AppStrings.gender,
                      value: child.gender.label,
                      icon: Icons.wc_outlined,
                    ),
                    InfoRow(
                      label: AppStrings.birthDate,
                      value: child.birthDate == null
                          ? null
                          : AppDateUtils.formatDate(child.birthDate!),
                      icon: Icons.cake_outlined,
                    ),
                    InfoRow(
                      label: AppStrings.age,
                      value: child.ageLabel,
                      icon: Icons.timelapse_outlined,
                    ),
                    InfoRow(
                      label: AppStrings.childMobile,
                      value: child.mobile,
                      icon: Icons.phone_outlined,
                      isPhone: true,
                    ),
                    InfoRow(
                      label: AppStrings.childCode,
                      value: child.code,
                      icon: Icons.tag,
                    ),
                    InfoRow(
                      label: AppStrings.currentClass,
                      value: data.className,
                      icon: Icons.class_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.parentsInfo,
                child: Column(
                  children: [
                    InfoRow(
                      label: AppStrings.motherName,
                      value: child.motherName,
                      icon: Icons.woman_outlined,
                    ),
                    InfoRow(
                      label: AppStrings.motherMobile,
                      value: child.motherMobile,
                      icon: Icons.phone_outlined,
                      isPhone: true,
                    ),
                    InfoRow(
                      label: AppStrings.fatherName,
                      value: child.fatherName,
                      icon: Icons.man_outlined,
                    ),
                    InfoRow(
                      label: AppStrings.fatherMobile,
                      value: child.fatherMobile,
                      icon: Icons.phone_outlined,
                      isPhone: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.churchInfo,
                child: InfoRow(
                  label: AppStrings.confessionFather,
                  value: child.confessionFather,
                  icon: Icons.church_outlined,
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.schoolInfo,
                child: Column(
                  children: [
                    InfoRow(
                      label: AppStrings.school,
                      value: child.school,
                      icon: Icons.apartment_outlined,
                    ),
                    InfoRow(
                      label: AppStrings.address,
                      value: child.address,
                      icon: Icons.location_on_outlined,
                    ),
                    InfoRow(
                      label: AppStrings.notes,
                      value: child.notes,
                      icon: Icons.notes_outlined,
                    ),
                    InfoRow(
                      label: AppStrings.createdAt,
                      value: child.createdAt == null
                          ? null
                          : AppDateUtils.formatDate(child.createdAt!),
                      icon: Icons.event_outlined,
                    ),
                    InfoRow(
                      label: AppStrings.updatedAt,
                      value: child.updatedAt == null
                          ? null
                          : AppDateUtils.formatDateTime(child.updatedAt!),
                      icon: Icons.update,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _lastActivityCard(data.lastActivity),
              if (data.monthly.isNotEmpty) ...[
                const SizedBox(height: 16),
                _monthlyCard(data.monthly),
              ],
              const SizedBox(height: 16),
              _historyCard(data),
              const SizedBox(height: 20),
              _actions(child, data.className, isAdmin),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  /// Opens the photo full width so a face is actually recognisable.
  Future<void> _viewPhoto(Child child) async {
    final url = await PhotoService.signedUrl(
      bucket: Db.bucketChildPhotos,
      path: child.photoPath,
    );
    if (url == null || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Icon(Icons.broken_image_outlined, size: 48),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                child.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(Child child, String className) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            GestureDetector(
              onTap: child.hasPhoto ? () => _viewPhoto(child) : null,
              child: ChildAvatar(child: child, size: 64),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      GenderBadge(gender: child.gender, compact: true),
                      Text(
                        className,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      if (child.ageLabel != null)
                        Text(
                          child.ageLabel!,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            StatusBadge(isActive: child.isActive),
          ],
        ),
      ),
    );
  }

  Widget _summary(ChildYearReport report, List<ChildMonthlyReport> monthly) {
    // Sessions held so far = sum of monthly sessionsTotal up to current month.
    final now = DateTime.now();
    final held = monthly
        .where((r) =>
            r.monthStart.year < now.year ||
            (r.monthStart.year == now.year &&
                r.monthStart.month <= now.month))
        .fold(0, (sum, r) => sum + r.sessionsTotal);
    final pct = held > 0 ? report.sessionsAttended / held * 100 : report.percentage;

    return SectionCard(
      title: AppStrings.attendanceSummary,
      child: Column(
        children: [
          PercentageBar(
            percentage: pct,
            label: AppStrings.averageAttendance,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metric(
                  AppStrings.totalPoints,
                  '${report.points}',
                ),
              ),
              Expanded(
                child: _metric(
                  AppStrings.attendedSessions,
                  '${report.sessionsAttended}/${held > 0 ? held : report.sessionsTotal}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }

  Widget _monthlyCard(List<ChildMonthlyReport> monthly) {
    return SectionCard(
      title: AppStrings.monthlyBreakdown,
      child: Column(
        children: monthly.map((row) {
          final isFiltered = _monthFilter != null &&
              _monthFilter!.year == row.monthStart.year &&
              _monthFilter!.month == row.monthStart.month;
          return InkWell(
            // Tapping a month scopes the history list below to it.
            onTap: () => setState(
              () => _monthFilter = isFiltered ? null : row.monthStart,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: isFiltered
                    ? AppColors.navy.withValues(alpha: 0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppDateUtils.formatMonth(row.monthStart),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isFiltered ? FontWeight.w800 : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '${row.sessionsAttended}/${row.sessionsTotal}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(width: 10),
                  ScoreChip(
                    score: row.points,
                    maxScore: row.maxPoints,
                    compact: true,
                    showMax: false,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// The last Saturday the child did each activity, newest information first.
  Widget _lastActivityCard(ChildLastActivity? activity) {
    return SectionCard(
      title: AppStrings.lastActivityTitle,
      child: Column(
        children: [
          _lastActivityRow(
            AppStrings.sundaySchoolShort,
            activity?.lastSundaySchool,
            Icons.menu_book_outlined,
          ),
          _lastActivityRow(
            AppStrings.vespersShort,
            activity?.lastVespers,
            Icons.nights_stay_outlined,
          ),
          _lastActivityRow(
            AppStrings.massShort,
            activity?.lastMass,
            Icons.church_outlined,
          ),
          _lastActivityRow(
            AppStrings.confessionShort,
            activity?.lastConfession,
            Icons.volunteer_activism_outlined,
          ),
        ],
      ),
    );
  }

  Widget _lastActivityRow(String label, DateTime? date, IconData icon) {
    return InfoRow(
      label: label,
      value: date == null
          ? AppStrings.neverAttended
          : '${AppDateUtils.formatDate(date)} • ${AppDateUtils.sinceLabel(date)}',
      icon: icon,
    );
  }

  Widget _historyCard(_ProfileData data) {
    final months = <DateTime>{
      for (final row in data.history)
        DateTime(row.sessionDate.year, row.sessionDate.month),
    }.toList()
      ..sort((a, b) => a.compareTo(b));

    final visible = data.history.where((row) {
      if (_monthFilter != null &&
          (row.sessionDate.year != _monthFilter!.year ||
              row.sessionDate.month != _monthFilter!.month)) {
        return false;
      }
      return switch (_presenceFilter) {
        _PresenceFilter.all => true,
        _PresenceFilter.present => row.isPresent,
        _PresenceFilter.absent => !row.isPresent,
      };
    }).toList();

    final isNarrowing =
        _monthFilter != null || _presenceFilter != _PresenceFilter.all;

    return SectionCard(
      title: AppStrings.attendanceHistory,
      trailing: isNarrowing
          ? IconButton(
              tooltip: AppStrings.clearFilters,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() {
                _monthFilter = null;
                _presenceFilter = _PresenceFilter.all;
              }),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 20),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (months.isNotEmpty) ...[
            DropdownButtonFormField<DateTime?>(
              initialValue: _monthFilter,
              isDense: true,
              decoration: const InputDecoration(
                labelText: AppStrings.month,
                prefixIcon: Icon(Icons.calendar_month_outlined),
              ),
              items: <DropdownMenuItem<DateTime?>>[
                const DropdownMenuItem<DateTime?>(
                  value: null,
                  child: Text(AppStrings.allMonths),
                ),
                ...months.map(
                  (month) => DropdownMenuItem<DateTime?>(
                    value: month,
                    child: Text(AppDateUtils.formatMonth(month)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _monthFilter = value),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _PresenceFilter.values
                    .map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(option.label),
                          selected: _presenceFilter == option,
                          onSelected: (_) =>
                              setState(() => _presenceFilter = option),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 4),
            Divider(color: AppColors.muted.withValues(alpha: 0.2)),
          ],
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                AppStrings.noData,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            ...visible.map(_historyRow),
          if (visible.isNotEmpty && isNarrowing) ...[
            const SizedBox(height: 8),
            Text(
              '${AppStrings.showingOf} ${visible.length} / ${data.history.length}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyRow(ChildSessionScore row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppDateUtils.formatDayDate(row.sessionDate),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  children: [
                    _flag(AppStrings.sundaySchoolShort, row.sundaySchool),
                    _flag(AppStrings.vespersShort, row.vespers),
                    _flag(AppStrings.massShort, row.mass),
                    _flag(AppStrings.confessionShort, row.confession),
                  ],
                ),
              ],
            ),
          ),
          ScoreChip(score: row.score, maxScore: row.maxScore, compact: true),
        ],
      ),
    );
  }

  Widget _flag(String label, bool present) {
    final color = present ? AppColors.success : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(present ? Icons.check : Icons.close, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(Child child, String className, bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => _edit(child),
          icon: const Icon(Icons.edit_outlined),
          label: const Text(AppStrings.editChild),
        ),
        if (isAdmin) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _move(child, className),
            icon: const Icon(Icons.swap_horiz),
            label: const Text(AppStrings.moveChild),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _toggleActive(child),
          style: OutlinedButton.styleFrom(
            foregroundColor:
                child.isActive ? AppColors.danger : AppColors.success,
            side: BorderSide(
              color: child.isActive ? AppColors.danger : AppColors.success,
            ),
          ),
          icon: Icon(
            child.isActive ? Icons.person_off_outlined : Icons.person_add_alt,
          ),
          label: Text(
            child.isActive ? AppStrings.deactivateChild : AppStrings.activateChild,
          ),
        ),
      ],
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.child,
    required this.className,
    required this.yearReport,
    required this.monthly,
    required this.history,
    required this.lastActivity,
  });

  final Child child;
  final String className;
  final ChildYearReport? yearReport;
  final List<ChildMonthlyReport> monthly;
  final List<ChildSessionScore> history;
  final ChildLastActivity? lastActivity;
}

class _MoveChildSheet extends StatefulWidget {
  const _MoveChildSheet({required this.classes, required this.currentClassName});

  final List<SchoolClass> classes;
  final String currentClassName;

  @override
  State<_MoveChildSheet> createState() => _MoveChildSheetState();
}

class _MoveChildSheetState extends State<_MoveChildSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            AppStrings.moveChild,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            AppStrings.moveChildBody,
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          InfoRow(
            label: AppStrings.currentClass,
            value: widget.currentClassName,
            icon: Icons.class_outlined,
          ),
          const SizedBox(height: 12),
          if (widget.classes.isEmpty)
            const Text(
              AppStrings.noClasses,
              style: TextStyle(color: AppColors.muted),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selected,
              decoration: const InputDecoration(labelText: AppStrings.newClass),
              items: widget.classes
                  .map((item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.name),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selected = value),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.of(context).pop(_selected),
            child: const Text(AppStrings.confirm),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.cancel),
          ),
        ],
      ),
    );
  }
}
