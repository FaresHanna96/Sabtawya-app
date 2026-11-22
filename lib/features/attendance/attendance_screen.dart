import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/celebration.dart';
import '../../core/widgets/class_filter_chips.dart';
import '../../core/widgets/class_group_header.dart';
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
import '../../data/models/event.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../data/supabase/db.dart';
import '../../state/session_controller.dart';
import '../events/event_detail_screen.dart' show showChildPaymentSheet;
import '../children/child_filters.dart';
import 'attendance_draft.dart';
import 'break_sheet.dart';

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

  /// The classes chosen; empty is "كل الفصول".
  Set<String> _classIds = <String>{};
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

  // ── live updates ──────────────────────────────────────────────────────────
  RealtimeChannel? _channel;

  /// The Saturdays the open channel listens to.
  Set<String> _watching = const <String>{};

  /// Who saved, by id, for the line that says who changed a mark.
  Map<String, String> _servantNames = const <String, String>{};

  /// Children whose line was just changed by somebody else (highlighted for a
  /// moment).
  final Set<String> _flashed = <String>{};
  Timer? _flashTimer;

  // ── finding a child ─────────────────────────────────────────────────────
  final _search = TextEditingController();
  String _query = '';

  /// One line per child instead of a card (remembered on this phone).
  bool _compact = false;

  // ── the bar that stays on top once the header scrolls away ──────────────
  final _scroll = ScrollController();
  final _headerKey = GlobalKey();
  bool _sticky = false;

  // ── unsaved marks kept on the phone ─────────────────────────────────────
  static final _drafts = AttendanceDraft.instance;
  Timer? _draftTimer;

  /// Saturdays with no lesson (by yyyy-MM-dd): a holiday or a نشاط ترفيهي.
  Map<String, LessonBreak> _breaks = const <String, LessonBreak>{};

  LessonBreak? get _break =>
      _date == null ? null : _breaks[AppDateUtils.toIsoDate(_date!)];

  bool get _isBreakDay =>
      _break != null || _sheets.any((s) => s.session.isBreak);

  Future<void> _loadBreaks() async {
    try {
      final b = await const LessonRepository().breaks();
      if (mounted) setState(() => _breaks = b);
    } catch (_) {
      // Without them there is just no "no lesson" warning.
    }
  }

  /// The admin: this Saturday is a holiday, a نشاط ترفيهي, or a normal day.
  Future<void> _setBreak() async {
    final date = _date;
    if (date == null) return;
    final picked = await showBreakSheet(
      context,
      date: date,
      current: _break,
      hasRecords: _entries.any((e) => e.isRecorded),
    );
    if (picked == null || !mounted) return;
    const repo = LessonRepository();
    final ok = await Ui.runGuarded(
      context,
      () => picked.kind == null
          ? repo.clearBreak(date)
          : repo.setBreak(date, shift: picked.shift, kind: picked.kind),
      successMessage: AppStrings.saved,
    );
    if (ok) {
      await _loadBreaks();
      await _load(quiet: true);
    }
  }

  // ── booking for the next نشاط ترفيهي ───────────────────────────────────
  static const _events = EventRepository();

  /// Events from today on, the nearest first, and the one being booked.
  List<Event> _upcoming = const <Event>[];
  Event? _bookingEvent;

  /// Each child's booking line for [_bookingEvent] (childId -> balance).
  Map<String, ChildEventBalance> _booking = const <String, ChildEventBalance>{};

  Future<void> _loadUpcoming() async {
    try {
      final list = await _events.upcomingEvents();
      if (!mounted || list.isEmpty) return;
      setState(() => _upcoming = list);
      _syncBooking();
    } catch (_) {
      // Without them there is just no booking button.
    }
  }

  /// The upcoming events that are not already past on the Saturday on
  /// screen: a trip on 28 Nov cannot be booked from the 12 Dec list.
  List<Event> get _bookable {
    final today = AppDateUtils.dateOnly(DateTime.now());
    var from = _date == null ? today : AppDateUtils.dateOnly(_date!);
    if (from.isBefore(today)) from = today;
    return [
      for (final e in _upcoming)
        if (!AppDateUtils.dateOnly(e.eventDate).isBefore(from)) e,
    ];
  }

  /// Keeps the event being booked among [_bookable] (none: the booking bar and
  /// buttons go away).
  void _syncBooking() {
    final list = _bookable;
    final keep = list.where((e) => e.id == _bookingEvent?.id);
    final next = keep.isNotEmpty ? keep.first : (list.isEmpty ? null : list.first);
    if (next?.id == _bookingEvent?.id) return;
    setState(() {
      _bookingEvent = next;
      _booking = const <String, ChildEventBalance>{};
    });
    if (next != null) unawaited(_loadBooking());
  }

  Future<void> _loadBooking() async {
    final event = _bookingEvent;
    if (event == null) return;
    try {
      final lines = await _events.balances(event.id);
      if (!mounted || _bookingEvent?.id != event.id) return;
      setState(() => _booking = {for (final b in lines) b.childId: b});
    } catch (_) {
      // Keeps what was shown.
    }
  }

  Future<void> _pickBookingEvent() async {
    final picked = await showModalBottomSheet<Event>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                AppStrings.pickEvent,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            for (final e in _bookable)
              ListTile(
                selected: e.id == _bookingEvent?.id,
                leading: const Icon(Icons.celebration_rounded, size: 20),
                title: Text(e.title),
                subtitle: Text(AppDateUtils.formatDayDate(e.eventDate)),
                onTap: () => Navigator.pop(context, e),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted || picked.id == _bookingEvent?.id) return;
    setState(() {
      _bookingEvent = picked;
      _booking = const <String, ChildEventBalance>{};
    });
    await _loadBooking();
  }

  /// Where this child stands for the event being booked; null hides the
  /// button (no upcoming event, or the line is not known).
  EntryBooking? _bookingOf(AttendanceEntry entry) {
    if (_bookingEvent == null) return null;
    final line = _booking[entry.child.id];
    if (line == null) return null;
    if (line.isPaid) return EntryBooking.paid;
    return line.reserved ? EntryBooking.reserved : EntryBooking.none;
  }

  /// Opens the event tab's own sheet for the child: pay, or reserve without
  /// paying. It is not an attendance mark, so it ignores the lock and the
  /// unsaved marks.
  Future<void> _toggleBooking(AttendanceEntry entry) async {
    final event = _bookingEvent;
    final line = _booking[entry.child.id];
    if (event == null || line == null) return;
    await showChildPaymentSheet(
      context,
      event: event,
      balance: line,
      onChanged: _loadBooking,
    );
    if (mounted) await _loadBooking();
  }

  /// "حجز: رحلة — السبت ٥/١٢" and how many of the children shown are booked.
  Widget _bookingBar() {
    final event = _bookingEvent!;
    final booked =
        _entries.where((e) => _booking[e.child.id]?.isBooked ?? false).length;
    final canPick = _bookable.length > 1;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.sky.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration_rounded, size: 18, color: AppColors.sky),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: canPick ? _pickBookingEvent : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${AppStrings.bookingFor(event.title)} • '
                        '${AppDateUtils.formatDayDate(event.eventDate)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (canPick)
                      const Icon(Icons.arrow_drop_down_rounded,
                          color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
          Text(
            AppStrings.bookedOf(booked, _entries.length),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.sky,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionController>();
    _classes = session.myClasses;
    _year = session.currentYear;
    _isAdmin = session.isAdmin;
    // An admin opens on "كل الفصول" (empty); a servant on their first class.
    _classIds = widget.initialClassId != null
        ? {widget.initialClassId!}
        : (_classes.isEmpty || (_isAdmin && _classes.length > 1))
            ? <String>{}
            : {_classes.first.classId};
    _date = widget.initialDate;
    _load();
    _scroll.addListener(_onScroll);
    _drafts.compact().then((on) {
      if (mounted && on) setState(() => _compact = true);
    });
    _loadBreaks();
    _loadUpcoming();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    // Whatever was marked in the last moment is kept too.
    if (_draftTimer?.isActive ?? false) unawaited(_writeDrafts());
    _draftTimer?.cancel();
    _search.dispose();
    _scroll.dispose();
    final channel = _channel;
    if (channel != null) Db.client.removeChannel(channel);
    super.dispose();
  }

  // ── live updates ──────────────────────────────────────────────────────────

  /// Listens to the Saturdays on screen, so a co-servant's save shows up here
  /// at once. Resubscribes only when the Saturdays on screen change.
  void _watch() {
    final ids = {for (final sheet in _sheets) sheet.session.id};
    if (setEquals(ids, _watching) && _channel != null) return;
    final old = _channel;
    if (old != null) Db.client.removeChannel(old);
    _channel = null;
    _watching = ids;
    if (ids.isEmpty) return;

    var seenFirst = false;
    _channel = Db.client
        .channel('attendance-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_records',
          filter: PostgresChangeFilter(
            type: ids.length == 1
                ? PostgresChangeFilterType.eq
                : PostgresChangeFilterType.inFilter,
            column: 'session_id',
            value: ids.length == 1 ? ids.first : ids.toList(),
          ),
          callback: _onRemote,
        )
        .subscribe((status, [error]) {
      if (status != RealtimeSubscribeStatus.subscribed) return;
      // Connected again after a drop: whatever was saved meanwhile is fetched.
      if (seenFirst) unawaited(_catchUp());
      seenFirst = true;
    });
    // The names are the same for every Saturday: read them once.
    if (_servantNames.isEmpty) unawaited(_loadServantNames());
  }

  Future<void> _loadServantNames() async {
    try {
      final people = await const ServantRepository().servants();
      if (!mounted) return;
      _servantNames = {for (final p in people) p.id: p.fullName};
    } catch (_) {
      // Without names the line just does not say who.
    }
  }

  void _onRemote(PostgresChangePayload payload) {
    if (!mounted || payload.eventType == PostgresChangeEvent.delete) return;
    final r = payload.newRecord;
    final by = r['updated_by'] as String?;
    _mergeRemote(
      sessionId: '${r['session_id']}',
      childId: '${r['child_id']}',
      sundaySchool: r['sunday_school'] == true,
      vespers: r['vespers'] == true,
      mass: r['mass'] == true,
      confession: r['confession'] == true,
      updatedAt: DateTime.tryParse('${r['updated_at']}')?.toLocal(),
      updatedByName: by == null ? null : _servantNames[by],
      mine: by != null && by == Db.userId,
    );
  }

  /// Fetches what the Saturdays on screen hold now and merges it, after the
  /// live connection was lost for a while.
  Future<void> _catchUp() async {
    try {
      for (final sheet in List.of(_sheets)) {
        final records = await _repository.recordsForSession(sheet.session.id);
        if (!mounted) return;
        for (final r in records) {
          _mergeRemote(
            sessionId: sheet.session.id,
            childId: r.childId,
            sundaySchool: r.sundaySchool,
            vespers: r.vespers,
            mass: r.mass,
            confession: r.confession,
            updatedAt: r.updatedAt,
            updatedByName: r.updatedByName,
            mine: false,
          );
        }
      }
    } catch (_) {
      // Still offline or refused: the next reconnect tries again.
    }
  }

  void _mergeRemote({
    required String sessionId,
    required String childId,
    required bool sundaySchool,
    required bool vespers,
    required bool mass,
    required bool confession,
    required DateTime? updatedAt,
    required String? updatedByName,
    required bool mine,
  }) {
    final i = [
      for (var k = 0; k < _entries.length; k++)
        if (_entrySheet[k].session.id == sessionId &&
            _entries[k].child.id == childId)
          k,
    ];
    if (i.isEmpty || i.first >= _original.length) return;
    final at = i.first;
    final changed = _entries[at].mergeRemote(
      _original[at],
      sundaySchool: sundaySchool,
      vespers: vespers,
      mass: mass,
      confession: confession,
      updatedAt: updatedAt,
      updatedByName: updatedByName,
    );
    if (!changed) return;
    setState(() {
      if (!mine) _flashed.add(childId);
    });
    if (mine) return;
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(_flashed.clear);
    });
  }

  bool get _hasChanges {
    if (_entries.length != _original.length) return false;
    for (var i = 0; i < _entries.length; i++) {
      if (!_entries[i].sameMarksAs(_original[i])) return true;
    }
    return false;
  }

  AttendanceSheet? get _sheet => _sheets.isEmpty ? null : _sheets.first;

  /// The classes on screen, in the order of the class list.
  List<String> get _shownClassIds => [
        for (final c in _classes)
          if (_classIds.isEmpty || _classIds.contains(c.classId)) c.classId,
      ];

  /// More than one class on screen ("كل الفصول" or several ticked).
  bool get _allClasses => _shownClassIds.length > 1;

  bool get _isLocked => !_allClasses && (_sheet?.session.isLocked ?? false);
  /// A Saturday with no lesson is shown but never taken (the database
  /// refuses it too); a locked one only by the admin.
  bool _canEditSheet(AttendanceSheet sheet) =>
      !sheet.session.isBreak && (!sheet.session.isLocked || _isAdmin);
  bool get _canEdit => _sheets.any(_canEditSheet);

  /// [quiet] keeps the roster on screen while it reloads (after a save or a
  /// lock), so the servant stays where they were instead of being sent back
  /// to the top behind a loading placeholder.
  Future<void> _load({bool quiet = false}) async {
    final year = _year;
    final classIds = _shownClassIds;
    if (classIds.isEmpty || year == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      if (!quiet) _loading = true;
      _error = null;
    });

    try {
      // One query for every chosen class's Saturdays, split per class here.
      final all = await _repository.sessionsForClasses(
        classIds: classIds,
        yearId: year.id,
      );
      final perClass = [
        for (final id in classIds)
          [
            for (final s in all)
              if (s.classId == id) s,
          ],
      ];

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
      // Every class's roster and records in two queries, not two per class.
      final sheets = await _repository.sheets(sessions: onDate, year: year);

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
      _watch();
      _syncBooking();
      if (_bookingEvent != null) unawaited(_loadBooking());
      if (!quiet) unawaited(_restoreDrafts());
    } catch (e) {
      if (!mounted) return;
      // A quiet reload follows a save that already succeeded: keep the
      // roster and just say the refresh failed.
      if (quiet) {
        Ui.error(context, e);
        return;
      }
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

  /// [classIds] empty is "كل الفصول".
  Future<void> _switchClass(Set<String> classIds) async {
    if (!await _confirmDiscard()) return;
    setState(() {
      _classIds = classIds;
      // The new classes have their own sessions; keep the date if it exists.
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
    final yes = await Ui.confirm(
      context,
      title: AppStrings.unsavedChanges,
      message: AppStrings.unsavedChangesBody,
      confirmLabel: AppStrings.discard,
      destructive: true,
    );
    if (yes) _clearDrafts();
    return yes;
  }

  // ── unsaved marks ──────────────────────────────────────────────────────

  /// Each session on screen with the indexes of its children.
  Map<AttendanceSheet, List<int>> _indexesBySheet() {
    final out = <AttendanceSheet, List<int>>{};
    for (var i = 0; i < _entries.length; i++) {
      (out[_entrySheet[i]] ??= []).add(i);
    }
    return out;
  }

  /// Keeps the marks a moment after the last tap (not on every tap).
  void _queueDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), _writeDrafts);
  }

  Future<void> _writeDrafts() async {
    if (_entries.length != _original.length) return;
    for (final e in _indexesBySheet().entries) {
      await _drafts.write(
        e.key.session.id,
        AttendanceDraft.changes(
          [for (final i in e.value) _entries[i]],
          [for (final i in e.value) _original[i]],
        ),
      );
    }
  }

  void _clearDrafts() {
    _draftTimer?.cancel();
    for (final sheet in _sheets) {
      unawaited(_drafts.clear(sheet.session.id));
    }
  }

  /// Puts back marks taken here before the app closed, unless a co-servant
  /// changed that child since; says so, with a way to drop them.
  Future<void> _restoreDrafts() async {
    final loaded = _sheets;
    var restored = 0;
    for (final e in _indexesBySheet().entries) {
      final draft = await _drafts.read(e.key.session.id);
      if (!mounted || !identical(_sheets, loaded)) return;
      if (draft.isEmpty) continue;
      restored += AttendanceDraft.restore(
        draft,
        [for (final i in e.value) _entries[i]],
        [for (final i in e.value) _original[i]],
        canEdit: (_) => _canEditSheet(e.key),
      );
    }
    if (restored == 0 || !mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.draftRestored(restored)),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: AppStrings.ignoreDraft,
          onPressed: _dropDraft,
        ),
      ),
    );
  }

  /// "تجاهل": back to the saved marks, and the draft is gone.
  void _dropDraft() {
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _entries.length && i < _original.length; i++) {
        final from = _original[i];
        _entries[i]
          ..sundaySchool = from.sundaySchool
          ..vespers = from.vespers
          ..mass = from.mass
          ..confession = from.confession;
      }
    });
    _clearDrafts();
  }

  // ── finding a child, compact rows, the bar on top ───────────────────────

  bool _visible(int i) {
    final e = _entries[i];
    return _query.trim().isEmpty || e.child.matches(_query);
  }

  void _toggleCompact() {
    setState(() => _compact = !_compact);
    unawaited(_drafts.setCompact(_compact));
  }

  void _onScroll() {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    final height = (box != null && box.hasSize) ? box.size.height : 320.0;
    final show = _scroll.hasClients && _scroll.offset > height;
    if (show != _sticky) setState(() => _sticky = show);
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
    _queueDraft();
  }

  /// Every child present (or cleared) in [only] one activity, or in all
  /// four when null. A locked class stays as it is (unless the admin).
  void _markAll(bool present, {AttendanceActivity? only}) {
    if (!_canEdit) return;
    HapticFeedback.mediumImpact();
    setState(() {
      markAllEntries(
        _entries,
        present: present,
        only: only,
        canEdit: (i) => _canEditSheet(_entrySheet[i]),
      );
    });
    _queueDraft();
  }

  /// "تحضير الجميع": which activity, or all of them.
  Future<void> _pickMarkAll() async {
    final picked = await showModalBottomSheet<int>(
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
            ListTile(
              leading: const Icon(Icons.done_all, color: AppColors.success),
              title: const Text(AppStrings.allActivities),
              onTap: () => Navigator.of(sheet).pop(-1),
            ),
            for (final a in AttendanceActivity.values)
              ListTile(
                leading: Icon(a.icon, color: AppColors.navy),
                title: Text(a.label),
                onTap: () => Navigator.of(sheet).pop(a.index),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _markAll(
      true,
      only: picked < 0 ? null : AttendanceActivity.values[picked],
    );
  }

  Future<void> _save() async {
    if (_sheets.isEmpty || !_canEdit) return;

    // Per class session: the marks changed here, plus an absent row for any
    // child who has none yet, so an absence is stored as a zero rather than
    // as missing data. Built so a co-servant's marks are never undone.
    final bySession =
        <String, (List<AttendanceEntry>, List<AttendanceEntry>)>{};
    for (var i = 0; i < _entries.length; i++) {
      final sheet = _entrySheet[i];
      if (!_canEditSheet(sheet)) continue;
      final lists = bySession[sheet.session.id] ??=
          (<AttendanceEntry>[], <AttendanceEntry>[]);
      lists.$1.add(_entries[i]);
      lists.$2.add(_original[i]);
    }
    final plans = <AttendanceSavePlan>[
      for (final e in bySession.entries)
        AttendanceSavePlan.build(
          sessionId: e.key,
          entries: e.value.$1,
          originals: e.value.$2,
        ),
    ].where((plan) => !plan.isEmpty).toList();
    if (plans.isEmpty) {
      Ui.info(context, AppStrings.saved);
      return;
    }

    // Saving writes an absence for everyone left unticked, which breaks
    // their runs (ملتزمين) and can send absence alerts: on a Saturday with no
    // lesson, or with nobody ticked at all, ask first.
    final editable = [
      for (var i = 0; i < _entries.length; i++)
        if (_canEditSheet(_entrySheet[i])) _entries[i],
    ];
    if (!mounted) return;
    if (nobodyPresent(editable) &&
        !await Ui.confirm(
          context,
          title: AppStrings.nobodyPresentTitle,
          message: AppStrings.nobodyPresentBody(editable.length),
          confirmLabel: AppStrings.saveAsAbsent,
          destructive: true,
        )) {
      return;
    }
    if (!mounted) return;

    final isOffline = !ConnectivityService.instance.isOnline;
    setState(() => _saving = true);
    final ok = await Ui.runGuarded(
      context,
      () async {
        // Each class is its own session: save them side by side instead of
        // one after another (with every class shown, that was 8 waits).
        await Future.wait(
            [for (final plan in plans) _repository.saveEntries(plan)]);
        // Whole Saturday written: now tell the servants about children whose
        // absences reached an alert level (online only; never fails the save).
        if (!isOffline) {
          await Future.wait([
            for (final sessionId in bySession.keys)
              _repository.checkAbsenceAlerts(sessionId),
          ]);
        }
      },
      successMessage: isOffline
          ? AppStrings.attendanceSavedOffline
          : AppStrings.attendanceSaved,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      // Saved (or queued to send): nothing left to keep on the side.
      _draftTimer?.cancel();
      for (final id in bySession.keys) {
        unawaited(_drafts.clear(id));
      }
      HapticFeedback.mediumImpact();
      if (!isOffline) Celebration.show(context);
      if (isOffline) {
        // Scores are DB-computed; skip reload while offline.
        // Commit local state so the unsaved-changes flag clears.
        setState(() {
          _original = _entries.map((e) => e.clone()).toList();
        });
      } else {
        // Reload so the scores come back from the database, in place.
        await _load(quiet: true);
      }
    }
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
    //
    // Built lazily: with "كل الفصول" the roster is ~200 cards, and building
    // them all up front made the screen slow to open. Rows are: the header,
    // the locked banner, then per class an optional header and its cards.
    // The search and "لم يُسجَّل حضورهم" only narrow what is listed; saving still
    // covers every child.
    final shown = [
      for (var i = 0; i < _entries.length; i++)
        if (_visible(i)) i,
    ];
    final rows = <Object>[
      #header,
      if (_isLocked) #locked,
      if (_entries.isEmpty) #empty else if (shown.isEmpty) #nomatch,
      for (var k = 0; k < shown.length; k++) ...[
        if (_allClasses &&
            (k == 0 || _entrySheet[shown[k]] != _entrySheet[shown[k - 1]]))
          _entrySheet[shown[k]],
        shown[k],
      ],
    ];
    final list = ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 96),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row == #header) {
          return KeyedSubtree(key: _headerKey, child: _header());
        }
        if (row == #locked) return _lockedBanner();
        if (row == #empty) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyState(
              icon: Icons.groups_outlined,
              title: AppStrings.noChildren,
              body: AppStrings.noChildrenBody,
            ),
          );
        }
        if (row == #nomatch) {
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: AppStrings.noSearchMatch,
              action: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _search.clear();
                  _query = '';
                }),
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text(AppStrings.clearFilters),
              ),
            ),
          );
        }
        if (row is AttendanceSheet) return _classHeader(row);
        final i = row as int;
        final highlight = _flashed.contains(_entries[i].child.id);
        final enabled = _canEditSheet(_entrySheet[i]);
        void onToggle(AttendanceActivity a) => _toggle(_entries[i], a);
        final booking = _bookingOf(_entries[i]);
        final VoidCallback? onBook =
            booking == null ? null : () => _toggleBooking(_entries[i]);
        if (_compact) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: AttendanceEntryRow(
              entry: _entries[i],
              highlight: highlight,
              enabled: enabled,
              onToggle: onToggle,
              booking: booking,
              onBook: onBook,
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: staggered(
            i,
            AttendanceEntryCard(
              entry: _entries[i],
              highlight: highlight,
              enabled: enabled,
              onToggle: onToggle,
              booking: booking,
              onBook: onBook,
            ),
          ),
        );
      },
    );

    return Stack(
      children: [
        list,
        // Once the header has scrolled away: the date and the count stay in
        // sight, and a tap goes back up to the search and the buttons.
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: IgnorePointer(
            ignoring: !_sticky,
            child: AnimatedSlide(
              offset: _sticky ? Offset.zero : const Offset(0, -1.2),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: _stickyBar(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stickyBar() {
    final total = _entries.length;
    final present = _entries.where((e) => e.sundaySchool).length;
    return Material(
      color: AppColors.card,
      elevation: 3,
      child: InkWell(
        onTap: () => _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.event_rounded, size: 18, color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _date == null ? '' : AppDateUtils.formatDayDate(_date!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${AppStrings.presentOf} $present ${AppStrings.ofWord} $total',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 4),
              const Tooltip(
                message: AppStrings.backToTop,
                child: Icon(Icons.keyboard_arrow_up_rounded,
                    color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The search box, the compact switch and "لم يُسجَّل حضورهم".
  Widget _finder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: AppStrings.attendanceSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: AppStrings.clearSearch,
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: _compact ? AppStrings.fullView : AppStrings.compactView,
              isSelected: _compact,
              onPressed: _toggleCompact,
              icon: const Icon(Icons.view_headline_rounded),
              selectedIcon: const Icon(Icons.view_agenda_outlined),
            ),
          ],
        ),
      ],
    );
  }

  /// "5 بنات — حضر 8 من 12" above each class when all classes are shown.
  Widget _classHeader(AttendanceSheet sheet) {
    final name = _classes
        .firstWhere((c) => c.classId == sheet.session.classId,
            orElse: () => _classes.first)
        .className;
    final present = sheet.entries.where((e) => e.sundaySchool).length;
    // The same header as every other list grouped by class, with this
    // class's lock and present count on the end.
    return ClassGroupHeader(
      name: name,
      count: sheet.entries.length,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sheet.session.isLocked) ...[
            const Icon(Icons.lock_outline, size: 16, color: AppColors.warning),
            const SizedBox(width: 6),
          ],
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
                selectedIds: _classIds,
                onChanged: _switchClass,
              )
            else
              Text(
                _classes.first.className,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 10),
            _dateNavigator(),
            if (_bookingEvent != null) ...[
              const SizedBox(height: 10),
              _bookingBar(),
            ],
            if (_isBreakDay) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _break?.kind == LessonBreakKind.activity
                          ? Icons.celebration_rounded
                          : Icons.beach_access_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          AppStrings.breakDayBanner(
                            (_break?.kind ?? LessonBreakKind.holiday).label,
                          ),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ),
                    if (_isAdmin)
                      TextButton(
                        onPressed: _setBreak,
                        child: const Text(AppStrings.change),
                      ),
                  ],
                ),
              ),
            ] else if (_isAdmin && _date != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _setBreak,
                  icon: const Icon(Icons.beach_access_outlined, size: 18),
                  label: const Text(AppStrings.markNoLesson),
                ),
              ),
            ],
            if (sheet != null) ...[
              const SizedBox(height: 12),
              _progress(),
              if (_canEdit) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _pickMarkAll,
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
              if (_entries.isNotEmpty) ...[
                const SizedBox(height: 12),
                _finder(),
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
    final present = _entries.where((e) => e.sundaySchool).length;
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

enum AttendanceActivity {
  sundaySchool(AppStrings.sundaySchoolShort, AppIcons.sundaySchool),
  vespers(AppStrings.vespersShort, AppIcons.vespers),
  mass(AppStrings.massShort, AppIcons.mass),
  confession(AppStrings.confessionShort, AppIcons.confession);

  const AttendanceActivity(this.label, this.icon);

  final String label;
  final IconData icon;

  bool on(AttendanceEntry e) => switch (this) {
        AttendanceActivity.sundaySchool => e.sundaySchool,
        AttendanceActivity.vespers => e.vespers,
        AttendanceActivity.mass => e.mass,
        AttendanceActivity.confession => e.confession,
      };
}

/// Nobody among [entries] has any activity ticked (and there is someone).
@visibleForTesting
bool nobodyPresent(List<AttendanceEntry> entries) =>
    entries.isNotEmpty && entries.every((e) => !e.isPresent);

/// Sets [only] (or all four activities when null) to [present] for every
/// entry [canEdit] allows.
@visibleForTesting
void markAllEntries(
  List<AttendanceEntry> entries, {
  required bool present,
  AttendanceActivity? only,
  required bool Function(int index) canEdit,
}) {
  for (var i = 0; i < entries.length; i++) {
    if (!canEdit(i)) continue;
    final e = entries[i];
    if (only == null || only == AttendanceActivity.sundaySchool) {
      e.sundaySchool = present;
    }
    if (only == null || only == AttendanceActivity.vespers) e.vespers = present;
    if (only == null || only == AttendanceActivity.mass) e.mass = present;
    if (only == null || only == AttendanceActivity.confession) {
      e.confession = present;
    }
  }
}

/// One child on one line: the name, then the four activities as round
/// buttons. About twice as many children fit on a screen as with the cards.
@visibleForTesting
/// Where a child stands for the upcoming نشاط ترفيهي being booked.
enum EntryBooking {
  /// No place booked yet.
  none,

  /// A place booked, not paid.
  reserved,

  /// Paid already (counts as booked).
  paid,
}

class AttendanceEntryRow extends StatelessWidget {
  const AttendanceEntryRow({
    super.key,
    required this.entry,
    required this.enabled,
    required this.onToggle,
    this.highlight = false,
    this.booking,
    this.onBook,
  });

  final AttendanceEntry entry;
  final bool enabled;
  final bool highlight;
  final ValueChanged<AttendanceActivity> onToggle;

  /// The booking mark shows only when an upcoming event is being booked.
  final EntryBooking? booking;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? AppColors.skyTint : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 6, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.child.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final a in AttendanceActivity.values)
              _RoundMark(
                activity: a,
                selected: a.on(entry),
                enabled: enabled,
                onTap: () => onToggle(a),
              ),
            if (booking != null) _BookMark(state: booking!, onTap: onBook),
          ],
        ),
      ),
    );
  }
}

/// The round bookmark on a compact line.
class _BookMark extends StatelessWidget {
  const _BookMark({required this.state, required this.onTap});

  final EntryBooking state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final paid = state == EntryBooking.paid;
    final on = state != EntryBooking.none;
    final color = paid ? AppColors.success : AppColors.sky;
    final label = switch (state) {
      EntryBooking.none => AppStrings.bookShort,
      EntryBooking.reserved => AppStrings.bookedShort,
      EntryBooking.paid => AppStrings.bookedPaidShort,
    };
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? color.withValues(alpha: 0.16) : null,
                  border: Border.all(
                    color: on
                        ? color.withValues(alpha: 0.6)
                        : AppColors.muted.withValues(alpha: 0.25),
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  on
                      ? Icons.bookmark_added_rounded
                      : Icons.bookmark_add_outlined,
                  size: 17,
                  color: on ? color : AppColors.muted.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundMark extends StatelessWidget {
  const _RoundMark({
    required this.activity,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AttendanceActivity activity;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const on = AppColors.success;
    final off = AppColors.muted.withValues(alpha: enabled ? 0.55 : 0.25);
    return Semantics(
      button: true,
      toggled: selected,
      enabled: enabled,
      label: activity.label,
      excludeSemantics: true,
      child: Tooltip(
        message: activity.label,
        child: InkResponse(
          onTap: enabled ? onTap : null,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? on.withValues(alpha: 0.16)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? on.withValues(alpha: 0.6)
                        : AppColors.muted.withValues(alpha: 0.25),
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  activity.icon,
                  size: 17,
                  color: selected ? on : off,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One child's line: four toggles and the score they add up to.
@visibleForTesting
class AttendanceEntryCard extends StatelessWidget {
  const AttendanceEntryCard({
    required this.entry,
    required this.enabled,
    required this.onToggle,
    this.highlight = false,
    this.booking,
    this.onBook,
  });

  /// The booking chip shows only when an upcoming event is being booked.
  final EntryBooking? booking;
  final VoidCallback? onBook;

  final AttendanceEntry entry;
  final bool enabled;

  /// Somebody else just changed this line.
  final bool highlight;
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
      color: highlight ? AppColors.skyTint : null,
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
                    if (booking != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _BookChip(state: booking!, onTap: onBook),
                      ),
                    ],
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

/// "حجز" / "محجوز" / "دفع" under a child's four toggles.
class _BookChip extends StatelessWidget {
  const _BookChip({required this.state, required this.onTap});

  final EntryBooking state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final paid = state == EntryBooking.paid;
    final on = state != EntryBooking.none;
    final color = paid ? AppColors.success : AppColors.sky;
    final label = switch (state) {
      EntryBooking.none => AppStrings.bookShort,
      EntryBooking.reserved => AppStrings.bookedShort,
      EntryBooking.paid => AppStrings.bookedPaidShort,
    };
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: 0.12) : null,
            border: Border.all(
              color: on
                  ? color.withValues(alpha: 0.45)
                  : AppColors.muted.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                paid
                    ? Icons.check_circle_rounded
                    : (on
                        ? Icons.bookmark_added_rounded
                        : Icons.bookmark_add_outlined),
                size: 15,
                color: on ? color : AppColors.muted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: on ? color : AppColors.muted,
                ),
              ),
            ],
          ),
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
