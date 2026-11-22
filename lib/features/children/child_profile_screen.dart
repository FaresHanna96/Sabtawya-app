import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/child_changes.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
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
import 'change_history_card.dart';
import 'child_attendance_log.dart';
import 'child_avatar.dart';
import 'child_location_card.dart';
import 'contact_cards.dart';
import 'child_filters.dart';
import 'child_form_screen.dart';
import 'health_notes_card.dart';
import 'location_sheet.dart';
import 'missing_info.dart';
import 'missing_info_banner.dart';

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

  Future<_ProfileData> _load() async {
    // Read before the first await, while the context is certainly mounted.
    final yearId = context.read<SessionController>().currentYear?.id;

    final child = await _children.byId(widget.childId);
    if (child == null) {
      throw AppFailure('لم يتم العثور على المخدوم');
    }

    // The reads below do not depend on each other: run them side by side
    // instead of one after another (the profile waited for each in turn).
    final (
      classOverview,
      yearReport,
      history,
      lastActivity,
      logs,
      changes,
      classSessions,
    ) = await (
      _classes.overviewById(child.classId),
      yearId == null
          ? Future.value(null)
          : _reports.childYear(childId: child.id, yearId: yearId),
      _attendance.childHistory(childId: child.id, yearId: yearId),
      _reports.lastActivity(child.id),
      _children.visitLogs(child.id),
      // Needs the network; offline or refused, the card just shows nothing.
      _children
          .changeHistory(child.id)
          .catchError((Object _) => const <ChildChange>[]),
      // The class's Saturdays, so one nobody recorded still shows in the log.
      yearId == null
          ? Future.value(const <AttendanceSession>[])
          : _attendance
              .sessionsForClasses(classIds: [child.classId], yearId: yearId)
              .catchError((Object _) => const <AttendanceSession>[]),
    ).wait;

    return _ProfileData(
      child: child,
      className: classOverview?.className ?? AppStrings.unknown,
      yearReport: yearReport,
      history: history,
      sessionDates: [
        for (final s in classSessions)
          if (!s.isBreak) s.sessionDate,
      ],
      breakDates: {
        for (final s in classSessions)
          if (s.isBreak) s.sessionDate,
      },
      lastActivity: lastActivity,
      visitLogs: logs,
      changes: changes,
    );
  }

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _edit(Child child) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => ChildFormScreen(child: child)),
    );
    if (changed == true) await _reload();
  }

  /// Puts back what one history line changed, newest edit first.
  Future<void> _undoChange(ChildChangeGroup group) async {
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.undoEditTitle,
      message: AppStrings.undoEditMessage,
      confirmLabel: AppStrings.undo,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await Ui.runGuarded(
      context,
      () async {
        for (final id in group.ids) {
          await _children.revertChange(id);
        }
      },
      successMessage: AppStrings.undoDone,
    );
    if (ok && mounted) {
      await context.read<SessionController>().refreshClasses();
      await _reload();
    }
  }

  Future<void> _setLocation(Child child) async {
    final saved = await showLocationSheet(
      context,
      childId: child.id,
      current: child.location,
    );
    if (saved && mounted) await _reload();
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
    final session = context.watch<SessionController>();
    final isAdmin = session.isAdmin;
    final canEdit = !session.isGeneralServant;

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
              FadeSlideIn(index: 0, child: _header(child, data.className)),
              const SizedBox(height: 12),
              // Calling the family is the most common reason to open a
              // profile, so the numbers sit right under the name.
              FadeSlideIn(index: 1, child: _contactBar(child)),
              const SizedBox(height: 12),
              // What the record is missing, and a way to ask the family.
              if (canEdit && MissingInfo.of(child).isNotEmpty) ...[
                FadeSlideIn(
                  index: 1,
                  child: MissingInfoBanner(
                    child: child,
                    servantName: session.displayName,
                    canEdit: canEdit,
                    onEdit: () => _edit(child),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Where the child lives: open it on the map, or get directions.
              FadeSlideIn(
                index: 1,
                child: ChildLocationCard(
                  location: child.location,
                  address: child.address,
                  onSet: canEdit ? () => _setLocation(child) : null,
                ),
              ),
              if (child.location != null || canEdit) const SizedBox(height: 12),
              // ملخص الحضور with every Saturday under it, in one card.
              FadeSlideIn(
                index: 2,
                child: ChildAttendanceLog(
                  history: data.history,
                  sessionDates: data.sessionDates,
                  breakDates: data.breakDates,
                  lastActivity: data.lastActivity,
                  points: data.yearReport?.points,
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.personalInfo,
                collapsible: true,
                initiallyExpanded: true,
                icon: Icons.badge_rounded,
                accent: AppColors.navyLight,
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
                      phoneActions: false,
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
                collapsible: true,
                initiallyExpanded: true,
                icon: Icons.family_restroom_rounded,
                accent: AppColors.coral,
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
                      phoneActions: false,
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
                      phoneActions: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.churchInfo,
                collapsible: true,
                initiallyExpanded: false,
                icon: Icons.church_rounded,
                accent: AppColors.maroon,
                child: Column(
                  children: [
                    InfoRow(
                      label: AppStrings.confessionFather,
                      value: child.confessionFather,
                      icon: Icons.church_outlined,
                    ),
                    if (child.gender == Gender.boy)
                      InfoRow(
                        label: AppStrings.deacon,
                        value: child.isDeacon ? AppStrings.yes : AppStrings.no,
                        icon: Icons.volunteer_activism_outlined,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.schoolInfo,
                collapsible: true,
                initiallyExpanded: false,
                icon: Icons.school_rounded,
                accent: AppColors.olive,
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
              if (canSeeHealthNotes(session, child.classId)) ...[
                HealthNotesCard(
                  key: ValueKey('health|${child.id}'),
                  childId: child.id,
                ),
                const SizedBox(height: 16),
              ],
              if (canEdit) ...[
                _VisitSection(
                  // Re-create when the stored visit changes (saved or a history
                  // entry deleted), so the fields show the new values.
                  key: ValueKey('${child.id}|${child.lastPhoneVisitDate}|'
                      '${child.lastPhoneVisitNotes}|${child.lastHomeVisitDate}|'
                      '${child.lastHomeVisitNotes}'),
                  child: child,
                  onSaved: _reload,
                ),
                const SizedBox(height: 16),
              ],
              _visitHistoryCard(data, canEdit),
              if (data.changes.isNotEmpty) ...[
                const SizedBox(height: 16),
                ChangeHistoryCard(
                  changes: data.changes,
                  onUndo: canEdit ? _undoChange : null,
                ),
              ],
              const SizedBox(height: 20),
              if (canEdit) _actions(child, data.className, isAdmin),
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

  /// One tap to call the child, the mother or the father (whichever numbers
  /// exist). Hidden when there is no number at all.
  Widget _contactBar(Child child) {
    return ContactCards(
      people: ContactPerson.forChild(child),
      childName: child.fullName,
      servantName: context.read<SessionController>().displayName,
    );
  }

  Widget _header(Child child, String className) {
    final tint = child.gender == Gender.boy ? AppColors.sky : AppColors.coral;
    return FadeSlideIn(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [tint.withValues(alpha: 0.22), Colors.white],
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              GestureDetector(
                onTap: child.hasPhoto ? () => _viewPhoto(child) : null,
                child: ChildAvatar(child: child, size: 72),
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
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        GenderBadge(gender: child.gender, compact: true),
                        _headerFact(Icons.class_outlined, className),
                        if (child.ageLabel != null)
                          _headerFact(Icons.cake_outlined, child.ageLabel!),
                      ],
                    ),
                  ],
                ),
              ),
              StatusBadge(isActive: child.isActive),
            ],
          ),
        ),
      ),
    );
  }

  /// A small icon and a few words under the child's name (class, age).
  Widget _headerFact(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Deletes one history entry, then points the card's "last visit" back at
  /// the newest entry that is left (only when the deleted one was the newest
  /// of its type, so older cards without history are left alone).
  Future<void> _deleteVisit(ChildVisitLog log, _ProfileData data) async {
    final yes = await Ui.confirm(
      context,
      title: AppStrings.deleteVisit,
      destructive: true,
      confirmLabel: AppStrings.delete,
    );
    if (!yes || !mounted) return;

    final sameType = data.visitLogs.where((l) => l.visitType == log.visitType);
    final wasNewest = sameType.isNotEmpty && sameType.first.id == log.id;
    final remaining = sameType.where((l) => l.id != log.id);

    final ok = await Ui.runGuarded(
      context,
      () async {
        await _children.deleteVisitLog(log.id);
        if (!wasNewest) return;
        final next = remaining.isEmpty ? null : remaining.first;
        final c = data.child;
        await _children.update(
          c.withVisits(
            phoneVisitDate:
                log.isPhone ? next?.visitDate : c.lastPhoneVisitDate,
            phoneVisitNotes: log.isPhone ? next?.notes : c.lastPhoneVisitNotes,
            homeVisitDate: log.isPhone ? c.lastHomeVisitDate : next?.visitDate,
            homeVisitNotes: log.isPhone ? c.lastHomeVisitNotes : next?.notes,
          ),
        );
      },
      successMessage: AppStrings.visitDeleted,
    );
    if (ok && mounted) await _reload();
  }

  Widget _visitHistoryCard(_ProfileData data, bool canEdit) {
    final logs = data.visitLogs;
    return SectionCard(
      title: AppStrings.visitHistory,
      icon: Icons.home_rounded,
      accent: AppColors.coral,
      collapsible: true,
      child: logs.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppStrings.noVisitHistory,
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: logs
                  .map((l) => _visitLogRow(l, canEdit ? data : null))
                  .toList(),
            ),
    );
  }

  Widget _visitLogRow(ChildVisitLog log, _ProfileData? deletable) {
    final isPhone = log.isPhone;
    final tint = isPhone ? AppColors.navy : AppColors.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Same tinted round icon as the change history, so the two logs
          // read as one family.
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPhone ? Icons.phone_callback_rounded : Icons.home_rounded,
              size: 15,
              color: tint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: AppDateUtils.formatDate(log.visitDate),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(
                        text: ' · ${AppDateUtils.sinceLabel(log.visitDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (log.recorderName != null && log.recorderName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      AppStrings.visitBy(log.recorderName!),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.navy,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                if (log.notes != null && log.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      log.notes!,
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (isPhone ? AppColors.navy : AppColors.success)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              // Each row's own type; "آخر" belongs only to the card's last
              // visit, not to every entry in the history.
              isPhone ? AppStrings.followUpPhone : AppStrings.followUpHome,
              style: TextStyle(
                fontSize: 12,
                color: isPhone ? AppColors.navy : AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (deletable != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.muted,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
              tooltip: AppStrings.delete,
              onPressed: () => _deleteVisit(log, deletable),
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
            child.isActive
                ? AppStrings.deactivateChild
                : AppStrings.activateChild,
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
    required this.history,
    required this.lastActivity,
    required this.visitLogs,
    this.sessionDates = const <DateTime>[],
    this.breakDates = const <DateTime>{},
    this.changes = const <ChildChange>[],
  });

  final Child child;
  final String className;
  final ChildYearReport? yearReport;
  final List<ChildSessionScore> history;

  /// The class's Saturdays this year, recorded or not.
  final List<DateTime> sessionDates;

  /// Its Saturdays with no lesson (إجازة / نشاط ترفيهي).
  final Set<DateTime> breakDates;
  final ChildLastActivity? lastActivity;
  final List<ChildVisitLog> visitLogs;
  final List<ChildChange> changes;
}

// ---------------------------------------------------------------------------
// Visits section — inline editable datepicker + notes for phone & home visits.
// ---------------------------------------------------------------------------

class _VisitSection extends StatefulWidget {
  const _VisitSection({super.key, required this.child, required this.onSaved});

  final Child child;
  final Future<void> Function() onSaved;

  @override
  State<_VisitSection> createState() => _VisitSectionState();
}

class _VisitSectionState extends State<_VisitSection> {
  static const _children = ChildRepository();

  late DateTime? _phoneDate;
  late DateTime? _homeDate;
  late final TextEditingController _phoneNotes;
  late final TextEditingController _homeNotes;

  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phoneDate = widget.child.lastPhoneVisitDate;
    _homeDate = widget.child.lastHomeVisitDate;
    _phoneNotes =
        TextEditingController(text: widget.child.lastPhoneVisitNotes ?? '');
    _homeNotes =
        TextEditingController(text: widget.child.lastHomeVisitNotes ?? '');
  }

  @override
  void dispose() {
    _phoneNotes.dispose();
    _homeNotes.dispose();
    super.dispose();
  }

  void _mark() => setState(() => _dirty = true);

  Future<void> _pickDate({required bool isPhone}) async {
    final current = isPhone ? _phoneDate : _homeDate;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: AppStrings.pickVisitDate,
    );
    if (picked == null) return;
    setState(() {
      if (isPhone) {
        _phoneDate = picked;
      } else {
        _homeDate = picked;
      }
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    FocusScope.of(context).unfocus();

    final phoneNotes =
        _phoneNotes.text.trim().isEmpty ? null : _phoneNotes.text.trim();
    final homeNotes =
        _homeNotes.text.trim().isEmpty ? null : _homeNotes.text.trim();

    final updated = widget.child.withVisits(
      phoneVisitDate: _phoneDate,
      phoneVisitNotes: phoneNotes,
      homeVisitDate: _homeDate,
      homeVisitNotes: homeNotes,
    );

    final ok = await Ui.runGuarded(
      context,
      () async {
        await _children.update(updated);
        // Record a history entry whenever the date OR the notes changed. A
        // corrected note on the same day updates the servant's own entry for
        // that day instead of adding a near-identical second one.
        String? clean(String? s) =>
            (s == null || s.trim().isEmpty) ? null : s.trim();
        final phoneChanged = _phoneDate != widget.child.lastPhoneVisitDate ||
            phoneNotes != clean(widget.child.lastPhoneVisitNotes);
        final homeChanged = _homeDate != widget.child.lastHomeVisitDate ||
            homeNotes != clean(widget.child.lastHomeVisitNotes);
        if (_phoneDate != null && phoneChanged) {
          await _children.recordVisitLog(
            childId: widget.child.id,
            visitType: 'phone',
            visitDate: _phoneDate!,
            notes: phoneNotes,
          );
        }
        if (_homeDate != null && homeChanged) {
          await _children.recordVisitLog(
            childId: widget.child.id,
            visitType: 'home',
            visitDate: _homeDate!,
            notes: homeNotes,
          );
        }
      },
      successMessage: AppStrings.visitsSaved,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _dirty = false;
    });
    if (ok) await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: AppStrings.visitsSection,
      icon: Icons.home_rounded,
      accent: AppColors.coral,
      collapsible: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _visitRow(
            label: AppStrings.lastPhoneVisit,
            icon: Icons.phone_callback_outlined,
            date: _phoneDate,
            notesController: _phoneNotes,
            isPhone: true,
          ),
          const SizedBox(height: 12),
          _visitRow(
            label: AppStrings.lastHomeVisit,
            icon: Icons.home_outlined,
            date: _homeDate,
            notesController: _homeNotes,
            isPhone: false,
          ),
          if (_dirty) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text(AppStrings.save),
            ),
          ],
        ],
      ),
    );
  }

  Widget _visitRow({
    required String label,
    required IconData icon,
    required DateTime? date,
    required TextEditingController notesController,
    required bool isPhone,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _pickDate(isPhone: isPhone),
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
              suffixIcon: date == null
                  ? const Icon(Icons.calendar_today_outlined, size: 20)
                  : IconButton(
                      tooltip: AppStrings.clearField,
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () => setState(() {
                        if (isPhone) {
                          _phoneDate = null;
                        } else {
                          _homeDate = null;
                        }
                        _dirty = true;
                      }),
                    ),
            ),
            child: Text(
              date == null
                  ? AppStrings.noVisitYet
                  : '${AppDateUtils.formatDate(date)} • ${AppDateUtils.sinceLabel(date)}',
              style: TextStyle(
                fontSize: 15,
                color: date == null ? AppColors.muted : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: notesController,
          maxLines: 2,
          onChanged: (_) => _mark(),
          decoration: const InputDecoration(
            labelText: AppStrings.visitNotes,
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _MoveChildSheet extends StatefulWidget {
  const _MoveChildSheet(
      {required this.classes, required this.currentClassName});

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
