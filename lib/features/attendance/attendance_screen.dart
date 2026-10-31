import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/attendance.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../state/session_controller.dart';
import '../children/child_filters.dart';

/// Takes attendance for one class on one Saturday.
///
/// The three activities are the only thing this screen writes; the score shown
/// next to each child is recomputed by the database on save, so what is on
/// screen after a save is exactly what is stored.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    this.showAppBar = false,
    this.initialClassId,
    this.initialDate,
  });

  final bool showAppBar;
  final String? initialClassId;
  final DateTime? initialDate;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const _repository = AttendanceRepository();

  late List<ClassOverview> _classes;
  AttendanceYear? _year;
  bool _isAdmin = false;

  String? _classId;
  DateTime? _date;

  List<AttendanceSession> _sessions = const <AttendanceSession>[];
  AttendanceSheet? _sheet;
  List<AttendanceEntry> _entries = <AttendanceEntry>[];
  List<AttendanceEntry> _original = <AttendanceEntry>[];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionController>();
    _classes = session.myClasses;
    _year = session.currentYear;
    _isAdmin = session.isAdmin;
    _classId = widget.initialClassId ??
        (_classes.isEmpty ? null : _classes.first.classId);
    _date = widget.initialDate;
    _load();
  }

  bool get _hasChanges {
    if (_entries.length != _original.length) return false;
    for (var i = 0; i < _entries.length; i++) {
      if (!_entries[i].sameMarksAs(_original[i])) return true;
    }
    return false;
  }

  bool get _isLocked => _sheet?.session.isLocked ?? false;
  bool get _canEdit => !_isLocked || _isAdmin;

  Future<void> _load() async {
    final classId = _classId;
    final year = _year;
    if (classId == null || year == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sessions =
          await _repository.sessions(classId: classId, yearId: year.id);
      final target = _resolveDate(sessions);
      final session = target == null
          ? null
          : sessions.firstWhere(
              (item) => AppDateUtils.isSameDay(item.sessionDate, target),
            );

      final sheet = session == null
          ? null
          : await _repository.sheet(session: session, year: year);

      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _date = target;
        _sheet = sheet;
        _entries = sheet?.entries ?? <AttendanceEntry>[];
        _original = _entries.map((entry) => entry.clone()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppFailure.from(e).message;
        _loading = false;
      });
    }
  }

  /// Keeps the chosen date when it still exists, otherwise defaults to this
  /// week's Saturday, then falls back to the most recent past Saturday.
  DateTime? _resolveDate(List<AttendanceSession> sessions) {
    if (sessions.isEmpty) return null;

    final chosen = _date;
    if (chosen != null &&
        sessions.any((s) => AppDateUtils.isSameDay(s.sessionDate, chosen))) {
      return chosen;
    }

    // Prefer this week's Saturday when a session exists for it.
    final thisSaturday = AppDateUtils.lastSaturday(DateTime.now());
    if (sessions.any((s) => AppDateUtils.isSameDay(s.sessionDate, thisSaturday))) {
      return thisSaturday;
    }

    final today = AppDateUtils.dateOnly(DateTime.now());
    final past = sessions
        .where((s) => !s.sessionDate.isAfter(today))
        .map((s) => s.sessionDate)
        .toList();
    return past.isNotEmpty ? past.last : sessions.first.sessionDate;
  }

  Future<void> _switchClass(String? classId) async {
    if (classId == null || classId == _classId) return;
    if (!await _confirmDiscard()) return;
    setState(() {
      _classId = classId;
      // The new class has its own sessions; keep the date if it has one.
    });
    await _load();
  }

  Future<void> _goToDate(DateTime date) async {
    if (_date != null && AppDateUtils.isSameDay(date, _date!)) return;
    if (!await _confirmDiscard()) return;
    setState(() => _date = date);
    await _load();
  }

  Future<void> _step(int offset) async {
    if (_date == null || _sessions.isEmpty) return;
    final index = _sessions.indexWhere(
      (s) => AppDateUtils.isSameDay(s.sessionDate, _date!),
    );
    final next = index + offset;
    if (next < 0 || next >= _sessions.length) return;
    await _goToDate(_sessions[next].sessionDate);
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    return Ui.confirm(
      context,
      title: AppStrings.unsavedChanges,
      message: AppStrings.unsavedChangesBody,
      confirmLabel: AppStrings.discard,
      destructive: true,
    );
  }

  void _toggle(AttendanceEntry entry, _Activity activity) {
    if (!_canEdit) return;
    setState(() {
      switch (activity) {
        case _Activity.sundaySchool:
          entry.sundaySchool = !entry.sundaySchool;
        case _Activity.vespers:
          entry.vespers = !entry.vespers;
        case _Activity.mass:
          entry.mass = !entry.mass;
        case _Activity.confession:
          entry.confession = !entry.confession;
      }
    });
  }

  void _markAll(bool present) {
    if (!_canEdit) return;
    setState(() {
      for (final entry in _entries) {
        entry.sundaySchool = present;
        entry.vespers = present;
        entry.mass = present;
        entry.confession = present;
      }
    });
  }

  Future<void> _save() async {
    final sheet = _sheet;
    if (sheet == null || !_canEdit) return;

    // Changed lines, plus any child who has no row yet: saving a Saturday
    // records every child, so an absence is stored as a zero rather than as
    // missing data.
    final changed = <AttendanceEntry>[];
    for (var i = 0; i < _entries.length; i++) {
      if (!_entries[i].sameMarksAs(_original[i]) || !_entries[i].isRecorded) {
        changed.add(_entries[i]);
      }
    }
    if (changed.isEmpty) {
      Ui.info(context, AppStrings.saved);
      return;
    }

    final isOffline = !ConnectivityService.instance.isOnline;
    setState(() => _saving = true);
    final ok = await Ui.runGuarded(
      context,
      () => _repository.saveEntries(
        sessionId: sheet.session.id,
        entries: changed,
      ),
      successMessage:
          isOffline ? AppStrings.attendanceSavedOffline : AppStrings.attendanceSaved,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      if (isOffline) {
        // Scores are DB-computed; skip reload while offline.
        // Commit local state so the unsaved-changes flag clears.
        setState(() {
          _original = _entries.map((e) => e.clone()).toList();
        });
      } else {
        // Reload so the scores come back from the database.
        await _load();
      }
    }
  }

  Future<void> _toggleLock() async {
    final sheet = _sheet;
    if (sheet == null) return;
    final locking = !sheet.session.isLocked;

    final confirmed = await Ui.confirm(
      context,
      title: locking ? AppStrings.lockSession : AppStrings.unlockSession,
      message: locking ? AppStrings.sessionLockedBody : null,
    );
    if (!confirmed || !mounted) return;

    final ok = await Ui.runGuarded(
      context,
      () => _repository.setLocked(sheet.session.id, locking),
      successMessage: AppStrings.saved,
    );
    if (ok && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_hasChanges) return;
        final discard = await _confirmDiscard();
        if (!discard || !mounted) return;
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text(AppStrings.attendanceTitle),
                actions: _appBarActions(),
              )
            : null,
        body: SafeArea(child: _body()),
        floatingActionButton: (_sheet == null || !_canEdit || !_hasChanges)
            ? null
            : FloatingActionButton.extended(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text(AppStrings.saveAttendance),
              ),
      ),
    );
  }

  List<Widget> _appBarActions() {
    if (!_isAdmin || _sheet == null) return const <Widget>[];
    return [
      IconButton(
        tooltip: _isLocked ? AppStrings.unlockSession : AppStrings.lockSession,
        onPressed: _toggleLock,
        icon: Icon(_isLocked ? Icons.lock_open : Icons.lock_outline),
      ),
    ];
  }

  Widget _body() {
    if (_year == null) {
      return const EmptyState(
        icon: Icons.event_busy_outlined,
        title: AppStrings.noSessionsTitle,
        body: AppStrings.noSessionsBody,
      );
    }
    if (_classes.isEmpty) {
      return const EmptyState(
        icon: Icons.class_outlined,
        title: AppStrings.noClassesAssigned,
        body: AppStrings.noClassesAssignedBody,
      );
    }
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final sheet = _sheet;
    if (sheet == null) {
      return Column(
        children: [
          _header(),
          const Expanded(
            child: EmptyState(
              icon: Icons.event_busy_outlined,
              title: AppStrings.noSessionsTitle,
              body: AppStrings.noSessionsBody,
            ),
          ),
        ],
      );
    }

    // One scroll view for the header and the roster. A nested list under a
    // fixed header left only the first child on screen (the other four sat
    // in a pane that did not receive the page scroll on web).
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _header(),
        if (_isLocked) _lockedBanner(),
        if (_entries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyState(
              icon: Icons.groups_outlined,
              title: AppStrings.noChildren,
              body: AppStrings.noChildrenBody,
            ),
          )
        else
          for (var i = 0; i < _entries.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _EntryCard(
                entry: _entries[i],
                enabled: _canEdit,
                onToggle: (activity) => _toggle(_entries[i], activity),
              ),
            ),
      ],
    );
  }

  Widget _header() {
    final sheet = _sheet;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: SectionCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_classes.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _classId,
                decoration:
                    const InputDecoration(labelText: AppStrings.classLabel),
                items: _classes
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.classId,
                        child: Text(item.className),
                      ),
                    )
                    .toList(),
                onChanged: _switchClass,
              )
            else
              Text(
                _classes.first.className,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  tooltip: AppStrings.attendanceDate,
                  onPressed: () => _step(-1),
                  icon: const Icon(Icons.chevron_right),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickSession,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            _date == null
                                ? AppStrings.selectSaturday
                                : AppDateUtils.formatDayDate(_date!),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            AppStrings.selectSaturday,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.attendanceDate,
                  onPressed: () => _step(1),
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            ),
            if (sheet != null) ...[
              const Divider(height: 20),
              Row(
                children: [
                  _HeaderStat(
                    label: AppStrings.presentCount,
                    value: '${sheet.presentCount}/${_entries.length}',
                  ),
                  _HeaderStat(
                    label: AppStrings.recordedCount,
                    value: '${sheet.recordedCount}/${_entries.length}',
                  ),
                  _HeaderStat(
                    label: AppStrings.totalPoints,
                    value: '${_totalScore()}/${sheet.maxScore}',
                  ),
                ],
              ),
              if (_canEdit) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _markAll(true),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text(AppStrings.markAllPresent),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _markAll(false),
                        icon: const Icon(Icons.remove_done, size: 18),
                        label: const Text(AppStrings.clearAll),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  int _totalScore() => _entries.fold(0, (sum, entry) => sum + entry.score);

  Widget _lockedBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isAdmin ? AppStrings.sessionLocked : AppStrings.sessionLockedBody,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSession() async {
    if (_sessions.isEmpty) return;

    final today = AppDateUtils.dateOnly(DateTime.now());
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _sessions.length,
          itemBuilder: (context, index) {
            // Show most-recent sessions at the top.
            final session = _sessions[_sessions.length - 1 - index];
            final selected = _date != null &&
                AppDateUtils.isSameDay(session.sessionDate, _date!);
            final future = session.sessionDate.isAfter(today);

            return ListTile(
              selected: selected,
              leading: Icon(
                session.isLocked
                    ? Icons.lock_outline
                    : (future ? Icons.schedule : Icons.event_available_outlined),
                size: 20,
                color: future ? AppColors.muted : AppColors.navy,
              ),
              title: Text(AppDateUtils.formatDayDate(session.sessionDate)),
              trailing: selected
                  ? const Icon(Icons.check, color: AppColors.olive)
                  : null,
              onTap: () => Navigator.of(context).pop(session.sessionDate),
            );
          },
        ),
      ),
    );

    if (picked != null) await _goToDate(picked);
  }
}

enum _Activity { sundaySchool, vespers, mass, confession }

/// One child's line: four toggles and the score they add up to.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.enabled,
    required this.onToggle,
  });

  final AttendanceEntry entry;
  final bool enabled;
  final ValueChanged<_Activity> onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.child.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GenderBadge(gender: entry.child.gender, compact: true),
                    ],
                  ),
                ),
                if (!entry.isRecorded)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.fiber_new_outlined,
                      size: 16,
                      color: AppColors.muted,
                    ),
                  ),
                ScoreChip(score: entry.score, maxScore: entry.maxScore, compact: true),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MarkToggle(
                  label: AppStrings.sundaySchoolShort,
                  points: entry.pointsSundaySchool,
                  selected: entry.sundaySchool,
                  enabled: enabled,
                  onTap: () => onToggle(_Activity.sundaySchool),
                ),
                const SizedBox(width: 6),
                _MarkToggle(
                  label: AppStrings.vespersShort,
                  points: entry.pointsVespers,
                  selected: entry.vespers,
                  enabled: enabled,
                  onTap: () => onToggle(_Activity.vespers),
                ),
                const SizedBox(width: 6),
                _MarkToggle(
                  label: AppStrings.massShort,
                  points: entry.pointsMass,
                  selected: entry.mass,
                  enabled: enabled,
                  onTap: () => onToggle(_Activity.mass),
                ),
                const SizedBox(width: 6),
                _MarkToggle(
                  label: AppStrings.confessionShort,
                  points: entry.pointsConfession,
                  selected: entry.confession,
                  enabled: enabled,
                  onTap: () => onToggle(_Activity.confession),
                ),
              ],
            ),
            if (entry.updatedByName != null) ...[
              const SizedBox(height: 6),
              Text(
                '${AppStrings.lastModifiedBy}: ${entry.updatedByName}'
                '${entry.updatedAt == null ? '' : ' • ${AppDateUtils.formatDateTime(entry.updatedAt!)}'}',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarkToggle extends StatelessWidget {
  const _MarkToggle({
    required this.label,
    required this.points,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final int points;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.olive : AppColors.muted;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.olive.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? AppColors.olive
                  : AppColors.muted.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: enabled ? color : AppColors.muted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                '+$points',
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}
