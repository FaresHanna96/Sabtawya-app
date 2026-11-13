import '../../core/utils/app_date_utils.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/arabic_sort.dart';
import '../models/attendance.dart';
import '../models/child.dart';
import '../supabase/db.dart';
import 'child_repository.dart';

class AttendanceRepository {
  const AttendanceRepository(
      {ChildRepository children = const ChildRepository()})
      : _children = children;

  final ChildRepository _children;

  // ------------------------------------------------------------------- years

  Future<List<AttendanceYear>> years() async {
    try {
      final data = await Db.client
          .from(Db.tAttendanceYears)
          .select()
          .order('start_date', ascending: false);
      return rows(data).map(AttendanceYear.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<AttendanceYear?> currentYear() async {
    try {
      final data = await Db.client
          .from(Db.tAttendanceYears)
          .select()
          .eq('is_current', true)
          .maybeSingle();
      return data == null ? null : AttendanceYear.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<String> createYear({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    int pointsSundaySchool = 5,
    int pointsVespers = 5,
    int pointsMass = 5,
    int pointsConfession = 5,
    bool makeCurrent = false,
  }) async {
    try {
      final data = await Db.client
          .from(Db.tAttendanceYears)
          .insert(<String, dynamic>{
            'name': name.trim(),
            'start_date': AppDateUtils.toIsoDate(startDate),
            'end_date': AppDateUtils.toIsoDate(endDate),
            'points_sunday_school': pointsSundaySchool,
            'points_vespers': pointsVespers,
            'points_mass': pointsMass,
            'points_confession': pointsConfession,
          })
          .select('id')
          .single();

      final yearId = data['id'].toString();
      if (makeCurrent) await setCurrentYear(yearId);
      return yearId;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> updateYear({
    required String yearId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required int pointsSundaySchool,
    required int pointsVespers,
    required int pointsMass,
    required int pointsConfession,
  }) async {
    try {
      await Db.client.from(Db.tAttendanceYears).update(<String, dynamic>{
        'name': name.trim(),
        'start_date': AppDateUtils.toIsoDate(startDate),
        'end_date': AppDateUtils.toIsoDate(endDate),
        'points_sunday_school': pointsSundaySchool,
        'points_vespers': pointsVespers,
        'points_mass': pointsMass,
        'points_confession': pointsConfession,
      }).eq('id', yearId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> setCurrentYear(String yearId) async {
    try {
      await Db.client.rpc<void>(
        'set_current_attendance_year',
        params: <String, dynamic>{'p_year_id': yearId},
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Creates one session per attendance weekday per active class. Safe to call
  /// repeatedly; existing sessions are left untouched.
  Future<int> generateSessions(
      {required String yearId, String? classId}) async {
    try {
      final inserted = await Db.client.rpc<dynamic>(
        'generate_sessions_for_year',
        params: <String, dynamic>{'p_year_id': yearId, 'p_class_id': classId},
      );
      return inserted is int ? inserted : int.tryParse('$inserted') ?? 0;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  // ---------------------------------------------------------------- sessions

  Future<List<AttendanceSession>> sessions({
    required String classId,
    required String yearId,
  }) async {
    try {
      final data = await Db.client
          .from(Db.tAttendanceSessions)
          .select()
          .eq('class_id', classId)
          .eq('year_id', yearId)
          // Oldest Saturday first. postgrest's order() is descending unless
          // told otherwise, which listed (and stepped through) them backwards.
          .order('session_date', ascending: true);
      return rows(data).map(AttendanceSession.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<SessionSummary>> sessionSummaries({
    required String classId,
    required String yearId,
  }) async {
    try {
      final data = await Db.client
          .from(Db.vClassSessionSummary)
          .select()
          .eq('class_id', classId)
          .eq('year_id', yearId)
          // Oldest Saturday first. postgrest's order() is descending unless
          // told otherwise, which listed (and stepped through) them backwards.
          .order('session_date', ascending: true);
      return rows(data).map(SessionSummary.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<AttendanceSession?> sessionOn({
    required String classId,
    required DateTime date,
  }) async {
    try {
      final data = await Db.client
          .from(Db.tAttendanceSessions)
          .select()
          .eq('class_id', classId)
          .eq('session_date', AppDateUtils.toIsoDate(date))
          .maybeSingle();
      return data == null ? null : AttendanceSession.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> setLocked(String sessionId, bool isLocked) async {
    try {
      await Db.client
          .from(Db.tAttendanceSessions)
          .update(<String, dynamic>{'is_locked': isLocked}).eq('id', sessionId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  // ------------------------------------------------------------------- sheet

  /// Builds one Saturday's sheet by joining the live class roster with whatever
  /// records exist. Nothing keeps a second child list, so a child added minutes
  /// ago is already on the sheet.
  Future<AttendanceSheet> sheet({
    required AttendanceSession session,
    required AttendanceYear year,
  }) async {
    // Alphabetical (Arabic) order, not the database's collation order.
    final roster = (await _children.byClass(session.classId))
      ..sort((a, b) => ArabicSort.compare(a.fullName, b.fullName));
    final records = await recordsForSession(session.id);
    final byChild = <String, AttendanceRecord>{
      for (final record in records) record.childId: record,
    };

    final entries = roster
        .map((child) => AttendanceEntry.from(
              child: child,
              record: byChild[child.id],
              year: year,
            ))
        .toList();

    return AttendanceSheet(session: session, year: year, entries: entries);
  }

  /// The Saturdays of several classes in one query (oldest first), for the
  /// attendance screen's "كل الفصول": one request instead of one per class.
  Future<List<AttendanceSession>> sessionsForClasses({
    required List<String> classIds,
    required String yearId,
  }) async {
    if (classIds.isEmpty) return const <AttendanceSession>[];
    try {
      final data = await Db.client
          .from(Db.tAttendanceSessions)
          .select()
          .inFilter('class_id', classIds)
          .eq('year_id', yearId)
          .order('session_date', ascending: true);
      return rows(data).map(AttendanceSession.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The sheets of several sessions (one per class) in two queries: every
  /// roster at once and every record at once, then split per session. The
  /// screen used to ask twice per class (about 16 requests for 8 classes).
  /// Sheets come back in the order of [sessions].
  Future<List<AttendanceSheet>> sheets({
    required List<AttendanceSession> sessions,
    required AttendanceYear year,
  }) async {
    if (sessions.isEmpty) return const <AttendanceSheet>[];
    if (sessions.length == 1) {
      return [await sheet(session: sessions.first, year: year)];
    }
    try {
      final classIds = {for (final s in sessions) s.classId}.toList();
      final (childRows, recordRows) = await (
        Db.client
            .from(Db.tChildren)
            .select()
            .inFilter('class_id', classIds)
            .eq('is_active', true),
        Db.client
            .from(Db.vSessionScores)
            .select()
            .inFilter('session_id', [for (final s in sessions) s.id]),
      ).wait;

      final rosterByClass = <String, List<Child>>{};
      for (final child in rows(childRows).map(Child.fromMap)) {
        (rosterByClass[child.classId] ??= <Child>[]).add(child);
      }
      final recordsBySession = <String, Map<String, AttendanceRecord>>{};
      for (final r in rows(recordRows).map(AttendanceRecord.fromMap)) {
        (recordsBySession[r.sessionId] ??= {})[r.childId] = r;
      }

      return [
        for (final session in sessions)
          AttendanceSheet(
            session: session,
            year: year,
            entries: [
              for (final child
                  in (rosterByClass[session.classId] ?? <Child>[])
                    ..sort(
                        (a, b) => ArabicSort.compare(a.fullName, b.fullName)))
                AttendanceEntry.from(
                  child: child,
                  record: recordsBySession[session.id]?[child.id],
                  year: year,
                ),
            ],
          ),
      ];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<AttendanceRecord>> recordsForSession(String sessionId) async {
    try {
      final data = await Db.client
          .from(Db.vSessionScores)
          .select()
          .eq('session_id', sessionId);
      return rows(data).map(AttendanceRecord.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Writes the three flags for each changed line. The database recomputes the
  /// score, so a tampered client cannot invent a grade.
  /// Offline, the write is queued by the HTTP layer and synced on reconnect.
  Future<void> saveEntries({
    required String sessionId,
    required List<AttendanceEntry> entries,
  }) async {
    if (entries.isEmpty) return;
    try {
      await Db.client.from(Db.tAttendanceRecords).upsert(
            entries.map((entry) => entry.toUpsertMap(sessionId)).toList(),
            onConflict: 'session_id,child_id',
          );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  // ----------------------------------------------------------------- history

  /// Saturday-by-Saturday history for one child, across classes so a move never
  /// hides earlier attendance.
  Future<List<ChildSessionScore>> childHistory({
    required String childId,
    String? yearId,
  }) async {
    try {
      var query =
          Db.client.from(Db.vSessionScores).select().eq('child_id', childId);
      if (yearId != null) query = query.eq('year_id', yearId);
      // Oldest Saturday first (postgrest sorts descending by default).
      final data = await query.order('session_date', ascending: true);
      return rows(data).map(ChildSessionScore.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<ChildSessionScore>> sessionScores(String sessionId) async {
    try {
      final data = await Db.client
          .from(Db.vSessionScores)
          .select()
          .eq('session_id', sessionId)
          .order('child_name');
      return rows(data).map(ChildSessionScore.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Convenience used by the export screen, which needs the roster and the
  /// records together for an arbitrary session.
  Future<List<Child>> rosterOf(String classId) =>
      _children.byClass(classId, includeInactive: false);
}
