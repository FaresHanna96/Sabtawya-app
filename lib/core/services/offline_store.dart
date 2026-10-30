import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/attendance.dart';

const _boxCache = 'attendance_cache';
const _boxQueue = 'write_queue';

class OfflineStore {
  const OfflineStore._();

  static Future<void> init() async {
    try {
      await Hive.openBox<dynamic>(_boxCache);
      await Hive.openBox<dynamic>(_boxQueue);
    } catch (_) {
      await Hive.deleteBoxFromDisk(_boxCache);
      await Hive.deleteBoxFromDisk(_boxQueue);
      try {
        await Hive.openBox<dynamic>(_boxCache);
        await Hive.openBox<dynamic>(_boxQueue);
      } catch (_) {}
    }
  }

  // ── cache helpers ──────────────────────────────────────────────────────────
  // Raw Supabase rows are stored directly (before parsing) so no re-serialisation
  // is needed — Child.fromMap / AttendanceSession.fromMap etc. reconstruct them.

  static Box<dynamic> get _cache => Hive.box<dynamic>(_boxCache);

  static Future<void> cacheChildren(
      String classId, List<Map<String, dynamic>> rows) =>
      _cache.put('children_$classId', rows);

  static List<Map<String, dynamic>>? getCachedChildren(String classId) {
    final v = _cache.get('children_$classId');
    if (v == null) return null;
    return (v as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> cacheSessions(
      String classId, String yearId, List<Map<String, dynamic>> rows) =>
      _cache.put('sessions_${classId}_$yearId', rows);

  static List<Map<String, dynamic>>? getCachedSessions(
      String classId, String yearId) {
    final v = _cache.get('sessions_${classId}_$yearId');
    if (v == null) return null;
    return (v as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> cacheRecords(
      String sessionId, List<Map<String, dynamic>> rows) =>
      _cache.put('records_$sessionId', rows);

  static List<Map<String, dynamic>>? getCachedRecords(String sessionId) {
    final v = _cache.get('records_$sessionId');
    if (v == null) return null;
    return (v as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ── write queue ────────────────────────────────────────────────────────────

  static Box<dynamic> get _queue => Hive.box<dynamic>(_boxQueue);

  static int pendingCount() => _queue.length;

  static Future<void> enqueueWrite(
      String sessionId, List<AttendanceEntry> entries) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _queue.put(id, <String, dynamic>{
      'id': id,
      'session_id': sessionId,
      'entries': entries.map((e) => e.toUpsertMap(sessionId)).toList(),
    });
  }

  static List<QueuedWrite> getPendingWrites() {
    return _queue.values
        .map((raw) => QueuedWrite.fromMap(Map<String, dynamic>.from(raw as Map)))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  static Future<void> removeWrite(String id) => _queue.delete(id);

  /// Merges the teacher's offline marks into the records cache so re-opening
  /// the sheet while still offline shows saved state, not stale server data.
  static Future<void> applyWriteToCache(
      String sessionId, List<AttendanceEntry> entries) async {
    final existing = getCachedRecords(sessionId) ?? <Map<String, dynamic>>[];
    final byChild = <String, Map<String, dynamic>>{
      for (final r in existing) r['child_id'] as String: r,
    };
    for (final e in entries) {
      byChild[e.child.id] = <String, dynamic>{
        'session_id': sessionId,
        'child_id': e.child.id,
        'sunday_school': e.sundaySchool,
        'vespers': e.vespers,
        'mass': e.mass,
        'confession': e.confession,
        'score': e.score,
        'max_score': e.maxScore,
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
    await cacheRecords(sessionId, byChild.values.toList());
  }
}

class QueuedWrite {
  const QueuedWrite({
    required this.id,
    required this.sessionId,
    required this.entries,
  });

  factory QueuedWrite.fromMap(Map<String, dynamic> m) => QueuedWrite(
        id: m['id'] as String,
        sessionId: m['session_id'] as String,
        entries: (m['entries'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );

  final String id;
  final String sessionId;
  final List<Map<String, dynamic>> entries;
}
