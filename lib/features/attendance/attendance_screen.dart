import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/celebration.dart';
import '../../core/widgets/class_filter_chips.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/attendance.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../state/session_controller.dart';
import '../children/child_filters.dart';

/// Takes attendance for one class on one Saturday, or for every class at
/// once ("كل الفصول"): one list grouped by class, each class still saved to
/// its own session.
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

  /// One session per Saturday, for the date arrows and the picker. With all
  /// classes it holds one session of each date that any class has.
  List<AttendanceSession> _sessions = const <AttendanceSession>[];

  /// The sheet of each class shown: one, or one per class for "كل الفصول".
  List<AttendanceSheet> _sheets = const <AttendanceSheet>[];

  /// Every child on screen, class after class, and the sheet each belongs to.
  List<AttendanceEntry> _entries = <AttendanceEntry>[];
  List<AttendanceSheet> _entrySheet = <AttendanceSheet>[];
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

  AttendanceSheet? get _sheet => _sheets.isEmpty ? null : _sheets.first;

  /// "كل الفصول": every class at once.
  bool get _allClasses => _classId == null && _classes.length > 1;

  bool get _isLocked => !_allClasses && (_sheet?.session.isLocked ?? false);
  bool _canEditSheet(AttendanceSheet sheet) =>
      !sheet.session.isLocked || _isAdmin;
  bool get _canEdit => _sheets.any(_canEditSheet);

  Future<void> _load() async {
    final year = _year;
    final classIds = _allClasses
        ? _classes.map((c) => c.classId).toList()
        : [if (_classId != null) _classId!];
    if (classIds.isEmpty || year == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final perClass = await Future.wait([
        for (final id in classIds)
          _repository.sessions(classId: id, yearId: year.id),
      ]);

      // One session per date for the arrows and the picker, oldest first.
      final byDate = <String, AttendanceSession>{};
      for (final list in perClass) {
        for (final s in list) {
          byDate.putIfAbsent(AppDateUtils.toIsoDate(s.sessionDate), () => s);
        }
      }
      final sessions = byDate.values.toList()
        ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

      final target = _resolveDate(sessions);
      // That Saturday's session in each class (in the order of the classes).
      final onDate = <AttendanceSession>[
        if (target != null)
          for (final list in perClass)
            for (final s in list)
              if (AppDateUtils.isSameDay(s.sessionDate, target)) s,
      ];
      final sheets = await Future.wait([
        for (final s in onDate) _repository.sheet(session: s, year: year),
      ]);

      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _date = target;
        _sheets = sheets;
        _entries = [for (final sh in sheets) ...sh.entries];
        _entrySheet = [
          for (final sh in sheets)
            for (final _ in sh.entries) sh,
        ];
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
    if (sessions
        .any((s) => AppDateUtils.isSameDay(s.sessionDate, thisSaturday))) {
      return thisSaturday;
    }

    final today = AppDateUtils.dateOnly(DateTime.now());
    final past = sessions
        .where((s) => !s.sessionDate.isAfter(today))
        .map((s) => s.sessionDate)
        .toList();
    return past.isNotEmpty ? past.last : sessions.first.sessionDate;
  }

  /// [classId] null is "كل الفصول".
  Future<void> _switchClass(String? classId) async {
    if (classId == _classId) return;
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

  void _toggle(AttendanceEntry entry, AttendanceActivity activity) {
    final i = _entries.indexOf(entry);
    if (i < 0 || !_canEditSheet(_entrySheet[i])) return;
    HapticFeedback.selectionClick();
    setState(() {
      switch (activity) {
        case AttendanceActivity.sundaySchool:
          entry.sundaySchool = !entry.sundaySchool;
        case AttendanceActivity.vespers:
          entry.vespers = !entry.vespers;
        case AttendanceActivity.mass:
          entry.mass = !entry.mass;
        case AttendanceActivity.confession:
          entry.confession = !entry.confession;
      }
    });
  }

  void _markAll(bool present) {
    if (!_canEdit) return;
    HapticFeedback.mediumImpact();
    setState(() {
      for (var i = 0; i < _entries.length; i++) {
        // A locked class stays as it is (unless the admin).
        if (!_canEditSheet(_entrySheet[i])) continue;
        final entry = _entries[i];
        entry.sundaySchool = present;
        entry.vespers = present;
        entry.mass = present;
        entry.confession = present;
      }
    });
  }

  Future<void> _save() async {
    if (_sheets.isEmpty || !_canEdit) return;

    // Changed lines, plus any child who has no row yet: saving a Saturday
    // records every child, so an absence is stored as a zero rather than as
    // missing data. Grouped by class session (one or many).
    final changedBySession = <String, List<AttendanceEntry>>{};
    for (var i = 0; i < _entries.length; i++) {
      final sheet = _entrySheet[i];
      if (!_canEditSheet(sheet)) continue;
      if (!_entries[i].sameMarksAs(_original[i]) || !_entries[i].isRecorded) {
        (changedBySession[sheet.session.id] ??= []).add(_entries[i]);
      }
    }
    if (changedBySession.isEmpty) {
      Ui.info(context, AppStrings.saved);
      return;
    }

    final isOffline = !ConnectivityService.instance.isOnline;
    setState(() => _saving = true);
    final ok = await Ui.runGuarded(
      context,
      () async {
        for (final e in changedBySession.entries) {
          await _repository.saveEntries(sessionId: e.key, entries: e.value);
        }
      },
      successMessage: isOffline
          ? AppStrings.attendanceSavedOffline
          : AppStrings.attendanceSaved,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      HapticFeedback.mediumImpact();
      if (!isOffline) Celebration.show(context);
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
                heroTag: null,
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text(AppStrings.saveAttendance),
              ),
      ),
    );
  }

  List<Widget> _appBarActions() {
    // Locking is per class: not offered while all classes are shown.
    if (!_isAdmin || _sheet == null || _allClasses) return const <Widget>[];
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
    if (_loading) return const SkeletonList();
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
          for (var i = 0; i < _entries.length; i++) ...[
            if (_allClasses && (i == 0 || _entrySheet[i] != _entrySheet[i - 1]))
              _classHeader(_entrySheet[i]),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: staggered(
                i,
                AttendanceEntryCard(
                  entry: _entries[i],
                  enabled: _canEditSheet(_entrySheet[i]),
                  onToggle: (activity) => _toggle(_entries[i], activity),
                ),
              ),
            ),
          ],
      ],
    );
  }

  /// "5 بنات — حضر 8 من 12" above each class when all classes are shown.
  Widget _classHeader(AttendanceSheet sheet) {
    final name = _classes
        .firstWhere((c) => c.classId == sheet.session.classId,
            orElse: () => _classes.first)
        .className;
    final present = sheet.entries.where((e) => e.isPresent).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          if (sheet.session.isLocked) ...[
            const SizedBox(width: 6),
            const Icon(Icons.lock_outline, size: 16, color: AppColors.warning),
          ],
          const Spacer(),
          Text(
            '${AppStrings.presentOf} $present ${AppStrings.ofWord} '
            '${sheet.entries.length}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final sheet = _sheet;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: SectionCard(
        icon: Icons.fact_check_rounded,
        accent: AppColors.sky,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_classes.length > 1)
              ClassFilterChips(
                classes: _classes
                    .map((c) =>
                        ClassFilterOption(id: c.classId, name: c.className))
                    .toList(),
                selectedId: _classId,
                onSelected: _switchClass,
              )
            else
              Text(
                _classes.first.className,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 10),
            _dateNavigator(),
            if (sheet != null) ...[
              const SizedBox(height: 12),
              _progress(),
              if (_canEdit) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _markAll(true),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text(AppStrings.markAllPresent),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _entries.any((e) => e.isPresent)
                          ? _confirmClearAll
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      icon: const Icon(Icons.remove_done, size: 18),
                      label: const Text(AppStrings.clearAll),
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

  /// Previous / next Saturday around the chosen date. The arrows grey out at
  /// the ends of the year, and the line under the date says how long ago it
  /// was (or that it is still to come).
  Widget _dateNavigator() {
    final index = _date == null
        ? -1
        : _sessions
            .indexWhere((s) => AppDateUtils.isSameDay(s.sessionDate, _date!));
    final canBack = index > 0;
    final canForward = index >= 0 && index < _sessions.length - 1;
    final today = AppDateUtils.dateOnly(DateTime.now());
    final upcoming = _date != null && _date!.isAfter(today);

    Widget arrow(IconData icon, bool enabled, int step) =>
        IconButton.filledTonal(
          tooltip: AppStrings.attendanceDate,
          onPressed: enabled ? () => _step(step) : null,
          icon: Icon(icon),
        );

    return Row(
      children: [
        arrow(AppIcons.back, canBack, -1),
        const SizedBox(width: 8),
        Expanded(
          child: Material(
            color: AppColors.navy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickSession,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Column(
                  children: [
                    Row(
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
                            _date == null
                                ? AppStrings.selectSaturday
                                : AppDateUtils.formatDayDate(_date!),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                    if (_date != null)
                      Text(
                        upcoming
                            ? AppStrings.upcomingSaturday
                            : AppDateUtils.sinceLabel(_date!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        arrow(AppIcons.forward, canForward, 1),
      ],
    );
  }

  /// "حضر 8 من 13" with a bar, a status badge (not taken / partly / done),
  /// and the points as a smaller line.
  Widget _progress() {
    final total = _entries.length;
    final present = _entries.where((e) => e.isPresent).length;
    final recorded = _entries.where((e) => e.isRecorded).length;
    final maxScore = _sheets.fold<int>(0, (sum, sh) => sum + sh.maxScore);
    final ratio = total == 0 ? 0.0 : present / total;

    final (statusText, statusColor) = recorded == 0
        ? (AppStrings.notTakenYet, AppColors.warning)
        : recorded < total
            ? (AppStrings.partlyTaken, AppColors.coral)
            : (AppStrings.takenDone, AppColors.success);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                children: [
                  const TextSpan(text: '${AppStrings.presentOf} '),
                  // The count rolls to its new value as children are marked.
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: present.toDouble()),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Text(
                        '${v.round()}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                  TextSpan(text: ' ${AppStrings.ofWord} $total'),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: ratio),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: AppColors.navy.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${AppStrings.recordedCount}: $recorded/$total',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const Spacer(),
            Text(
              '${AppStrings.totalPoints}: ${_totalScore()}/$maxScore',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }

  /// Clearing wipes every mark on screen in one tap, so ask first.
  Future<void> _confirmClearAll() async {
    final yes = await Ui.confirm(
      context,
      title: AppStrings.clearAllConfirm,
      message: AppStrings.clearAllConfirmBody,
      confirmLabel: AppStrings.clearAll,
      destructive: true,
    );
    if (yes && mounted) _markAll(false);
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
              _isAdmin
                  ? AppStrings.sessionLocked
                  : AppStrings.sessionLockedBody,
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
    // Oldest first, opened on the selected Saturday (or the one nearest today).
    final ordered = [..._sessions]
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    var focus = ordered.indexWhere(
      (s) => _date != null && AppDateUtils.isSameDay(s.sessionDate, _date!),
    );
    if (focus < 0) {
      focus = ordered.indexWhere((s) => !s.sessionDate.isBefore(today));
    }
    if (focus < 0) focus = ordered.length - 1;
    const tileHeight = 56.0;
    final controller = ScrollController(
      initialScrollOffset:
          (focus * tileHeight - tileHeight * 2).clamp(0.0, double.infinity),
    );

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          controller: controller,
          shrinkWrap: true,
          itemExtent: tileHeight,
          itemCount: ordered.length,
          itemBuilder: (context, index) {
            final session = ordered[index];
            final selected = _date != null &&
                AppDateUtils.isSameDay(session.sessionDate, _date!);
            final future = session.sessionDate.isAfter(today);

            return ListTile(
              selected: selected,
              leading: Icon(
                session.isLocked
                    ? Icons.lock_outline
                    : (future
                        ? Icons.schedule
                        : Icons.event_available_outlined),
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

    controller.dispose();
    if (picked != null) await _goToDate(picked);
  }
}

enum AttendanceActivity { sundaySchool, vespers, mass, confession }

/// One child's line: four toggles and the score they add up to.
@visibleForTesting
class AttendanceEntryCard extends StatelessWidget {
  const AttendanceEntryCard({
    required this.entry,
    required this.enabled,
    required this.onToggle,
  });

  final AttendanceEntry entry;
  final bool enabled;
  final ValueChanged<AttendanceActivity> onToggle;

  Color get _accentColor {
    if (!entry.isRecorded) return AppColors.muted;
    if (entry.maxScore <= 0) return AppColors.muted;
    final ratio = entry.score / entry.maxScore;
    if (ratio >= 0.8) return AppColors.success;
    if (ratio >= 0.4) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: _accentColor),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              GenderBadge(
                                  gender: entry.child.gender, compact: true),
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
                        ScoreChip(
                            score: entry.score,
                            maxScore: entry.maxScore,
                            compact: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MarkToggle(
                          // The longest label gets the widest button, so all
                          // four read in full on a 375px phone.
                          flex: 13,
                          label: AppStrings.sundaySchoolShort,
                          points: entry.pointsSundaySchool,
                          selected: entry.sundaySchool,
                          enabled: enabled,
                          onTap: () =>
                              onToggle(AttendanceActivity.sundaySchool),
                        ),
                        const SizedBox(width: 4),
                        _MarkToggle(
                          label: AppStrings.vespersShort,
                          points: entry.pointsVespers,
                          selected: entry.vespers,
                          enabled: enabled,
                          onTap: () => onToggle(AttendanceActivity.vespers),
                        ),
                        const SizedBox(width: 4),
                        _MarkToggle(
                          label: AppStrings.massShort,
                          points: entry.pointsMass,
                          selected: entry.mass,
                          enabled: enabled,
                          onTap: () => onToggle(AttendanceActivity.mass),
                        ),
                        const SizedBox(width: 4),
                        _MarkToggle(
                          label: AppStrings.confessionShort,
                          points: entry.pointsConfession,
                          selected: entry.confession,
                          enabled: enabled,
                          onTap: () => onToggle(AttendanceActivity.confession),
                        ),
                      ],
                    ),
                    if (entry.updatedByName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${AppStrings.lastModifiedBy}: ${entry.updatedByName}'
                        '${entry.updatedAt == null ? '' : ' • ${AppDateUtils.formatDateTime(entry.updatedAt!)}'}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
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
    this.flex = 9,
  });

  final String label;
  final int points;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.success;
    final labelColor = selected
        ? activeColor
        : (enabled ? AppColors.muted : AppColors.muted.withValues(alpha: 0.4));

    return Expanded(
      flex: flex,
      child: Semantics(
        button: true,
        enabled: enabled,
        toggled: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            transform: Matrix4.diagonal3Values(
                selected ? 1.04 : 1, selected ? 1.04 : 1, 1),
            transformAlignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            decoration: BoxDecoration(
              color: selected
                  ? activeColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              border: Border.all(
                color: selected
                    ? activeColor.withValues(alpha: 0.45)
                    : AppColors.muted.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            // The label is never cut: it shrinks a little on very narrow
            // screens instead of ending in "…". The check only appears once
            // marked, which leaves the unmarked label the whole button.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: labelColor),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
