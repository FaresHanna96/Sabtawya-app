import 'package:hive/hive.dart';

import '../../data/models/attendance.dart';

/// Marks taken on this phone but not saved yet, kept per Saturday (session)
/// so closing the app, a call or a crash does not lose them. Also remembers
/// whether the roster is shown in compact rows.
///
/// Each child's change is kept as "before>after" (four 0/1 marks each:
/// مدارس الأحد، عشية، قداس، اعتراف). It is put back only while the saved
/// marks still equal "before": when a co-servant changed that child since,
/// their marks win and the draft for that child is dropped.
class AttendanceDraft {
  AttendanceDraft({Future<Box<dynamic>> Function()? open})
      : _open = open ?? (() => Hive.openBox<dynamic>(_boxName)),
        _memory = null;

  /// Kept in memory only, for tests.
  AttendanceDraft.memory()
      : _open = null,
        _memory = <String, Object?>{};

  static const _boxName = 'attendance_drafts';
  static const _compactKey = 'pref:compact';

  /// A draft older than this is stale (that Saturday has long been dealt
  /// with) and is dropped instead of restored.
  static const keepFor = Duration(days: 14);

  /// The one the app uses.
  static final AttendanceDraft instance = AttendanceDraft();

  final Future<Box<dynamic>> Function()? _open;
  final Map<String, Object?>? _memory;
  Box<dynamic>? _box;

  Future<Box<dynamic>?> _ready() async {
    try {
      return _box ??= await _open!();
    } catch (_) {
      return null; // without the box there is just no draft
    }
  }

  Future<Object?> _get(String key) async {
    if (_memory != null) return _memory[key];
    return (await _ready())?.get(key);
  }

  Future<void> _put(String key, Object? value) async {
    if (_memory != null) {
      value == null ? _memory.remove(key) : _memory[key] = value;
      return;
    }
    final box = await _ready();
    if (value == null) {
      await box?.delete(key);
    } else {
      await box?.put(key, value);
    }
  }

  // ── compact rows ────────────────────────────────────────────────────────────

  Future<bool> compact() async => await _get(_compactKey) == true;

  Future<void> setCompact(bool on) => _put(_compactKey, on);

  // ── drafts ──────────────────────────────────────────────────────────────────

  /// The draft of [sessionId] (child id -> "before>after"), or empty.
  Future<Map<String, String>> read(String sessionId, {DateTime? now}) async {
    final raw = await _get('session:$sessionId');
    if (raw is! Map) return const {};
    final at = DateTime.tryParse('${raw['at']}');
    if (at == null || (now ?? DateTime.now()).difference(at) > keepFor) {
      await clear(sessionId);
      return const {};
    }
    final marks = raw['marks'];
    if (marks is! Map) return const {};
    return {for (final e in marks.entries) '${e.key}': '${e.value}'};
  }

  /// Keeps [changes] for [sessionId]; nothing to keep clears it.
  Future<void> write(
    String sessionId,
    Map<String, String> changes, {
    DateTime? now,
  }) {
    if (changes.isEmpty) return clear(sessionId);
    return _put('session:$sessionId', {
      'at': (now ?? DateTime.now()).toIso8601String(),
      'marks': changes,
    });
  }

  Future<void> clear(String sessionId) => _put('session:$sessionId', null);

  // ── the pure parts ──────────────────────────────────────────────────────────

  /// "1010": مدارس الأحد، عشية، قداس، اعتراف.
  static String marksOf(AttendanceEntry e) => [
        e.sundaySchool,
        e.vespers,
        e.mass,
        e.confession,
      ].map((on) => on ? '1' : '0').join();

  /// The children whose marks differ from [originals], as "before>after".
  static Map<String, String> changes(
    List<AttendanceEntry> entries,
    List<AttendanceEntry> originals,
  ) {
    final out = <String, String>{};
    for (var i = 0; i < entries.length && i < originals.length; i++) {
      final before = marksOf(originals[i]);
      final after = marksOf(entries[i]);
      if (before != after) out[entries[i].child.id] = '$before>$after';
    }
    return out;
  }

  /// Puts [draft] back on [entries] where the saved marks ([originals]) are
  /// still what the draft started from and [canEdit] allows it. Returns how
  /// many children got their unsaved marks back.
  static int restore(
    Map<String, String> draft,
    List<AttendanceEntry> entries,
    List<AttendanceEntry> originals, {
    bool Function(int index)? canEdit,
  }) {
    var restored = 0;
    for (var i = 0; i < entries.length && i < originals.length; i++) {
      final change = draft[entries[i].child.id];
      if (change == null || canEdit?.call(i) == false) continue;
      final parts = change.split('>');
      if (parts.length != 2 || parts[1].length != 4) continue;
      // Changed by somebody else since: their marks stand.
      if (parts[0] != marksOf(originals[i])) continue;
      final m = parts[1];
      entries[i]
        ..sundaySchool = m[0] == '1'
        ..vespers = m[1] == '1'
        ..mass = m[2] == '1'
        ..confession = m[3] == '1';
      restored++;
    }
    return restored;
  }
}
