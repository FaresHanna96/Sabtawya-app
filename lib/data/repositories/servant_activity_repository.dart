import '../models/attendance.dart';
import '../models/profile.dart';
import '../models/servant_activity.dart';
import '../supabase/db.dart';
import '../../core/utils/app_failure.dart';

/// Servant self-reporting (lesson prep) and admin-recorded attendance.
class ServantActivityRepository {
  const ServantActivityRepository();

  // ----------------------------------------------------------------- servant

  /// The servant's own lesson prep for [sessionId], or null if not yet submitted.
  Future<LessonPrep?> lessonPrepForSession(String sessionId) async {
    try {
      final data = await Db.client
          .from(Db.tServantLessonPreps)
          .select(
            'id, servant_id, session_id, status, admin_comment, '
            'reviewed_by, reviewed_at, created_at, '
            'servant_lesson_prep_photos(id, prep_id, storage_path, created_at), '
            'attendance_sessions!inner(session_date), '
            'profiles!servant_lesson_preps_servant_id_fkey(full_name)',
          )
          .eq('session_id', sessionId)
          .eq('servant_id', Db.userId!)
          .maybeSingle();
      if (data == null) return null;
      return LessonPrep.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Creates a lesson prep row for [sessionId] and returns the new record.
  /// Photos are added separately via [addPrepPhoto].
  Future<LessonPrep> createLessonPrep(String sessionId) async {
    try {
      await Db.client.from(Db.tServantLessonPreps).insert(<String, dynamic>{
        'servant_id': Db.userId,
        'session_id': sessionId,
      });
      return (await lessonPrepForSession(sessionId))!;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Inserts a photo record for an existing prep.
  Future<void> addPrepPhoto({
    required String prepId,
    required String storagePath,
  }) async {
    try {
      await Db.client
          .from(Db.tServantLessonPrepPhotos)
          .insert(<String, dynamic>{
            'prep_id': prepId,
            'storage_path': storagePath,
          });
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Sessions for the given class IDs in the given year, oldest first.
  Future<List<AttendanceSession>> sessionsForClasses(
    List<String> classIds, {
    String? yearId,
  }) async {
    if (classIds.isEmpty) return [];
    try {
      var query = Db.client
          .from(Db.tAttendanceSessions)
          .select('id, year_id, class_id, session_date, is_locked, notes')
          .inFilter('class_id', classIds);
      if (yearId != null) query = query.eq('year_id', yearId);
      final data = await query.order('session_date', ascending: true);
      return rows(data).map(AttendanceSession.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// All lesson preps for the signed-in servant, newest first.
  Future<List<LessonPrep>> myLessonPreps() async {
    try {
      final data = await Db.client
          .from(Db.tServantLessonPreps)
          .select(
            'id, servant_id, session_id, status, admin_comment, '
            'reviewed_by, reviewed_at, created_at, '
            'servant_lesson_prep_photos(id, prep_id, storage_path, created_at), '
            'attendance_sessions!inner(session_date), '
            'profiles!servant_lesson_preps_servant_id_fkey(full_name)',
          )
          .eq('servant_id', Db.userId!)
          .order('created_at', ascending: false);
      return rows(data).map(LessonPrep.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  // ------------------------------------------------------------------- admin

  /// All lesson preps for [servantId], newest first.
  Future<List<LessonPrep>> prepsForServant(String servantId) async {
    try {
      final data = await Db.client
          .from(Db.tServantLessonPreps)
          .select(
            'id, servant_id, session_id, status, admin_comment, '
            'reviewed_by, reviewed_at, created_at, '
            'servant_lesson_prep_photos(id, prep_id, storage_path, created_at), '
            'attendance_sessions!inner(session_date), '
            'profiles!servant_lesson_preps_servant_id_fkey(full_name)',
          )
          .eq('servant_id', servantId)
          .order('created_at', ascending: false);
      return rows(data).map(LessonPrep.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// All pending lesson preps across all servants.
  Future<List<LessonPrep>> allPendingPreps() async {
    try {
      final data = await Db.client
          .from(Db.tServantLessonPreps)
          .select(
            'id, servant_id, session_id, status, admin_comment, '
            'reviewed_by, reviewed_at, created_at, '
            'servant_lesson_prep_photos(id, prep_id, storage_path, created_at), '
            'attendance_sessions!inner(session_date), '
            'profiles!servant_lesson_preps_servant_id_fkey(full_name)',
          )
          .eq('status', 'pending')
          .order('created_at', ascending: true);
      return rows(data).map(LessonPrep.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Sets status (and optional comment) on a lesson prep submission.
  Future<void> reviewPrep({
    required String prepId,
    required String status,
    String? comment,
  }) async {
    try {
      await Db.client
          .from(Db.tServantLessonPreps)
          .update(<String, dynamic>{
            'status': status,
            'admin_comment': comment,
            'reviewed_by': Db.userId,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', prepId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  // ------------------------------------------------- attendance (admin only)

  /// All attendance records for [servantId] filtered by [activityType].
  Future<List<ServantAttendance>> attendancesForServant(
    String servantId,
    String activityType,
  ) async {
    try {
      final data = await Db.client
          .from(Db.tServantAttendances)
          .select()
          .eq('servant_id', servantId)
          .eq('activity_type', activityType)
          .order('date', ascending: false);
      return rows(data).map(ServantAttendance.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> recordAttendance({
    required String servantId,
    required String activityType,
    required DateTime date,
  }) async {
    try {
      await Db.client.from(Db.tServantAttendances).insert(<String, dynamic>{
        'servant_id': servantId,
        'activity_type': activityType,
        'date': date.toIso8601String().substring(0, 10),
        'recorded_by': Db.userId,
      });
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> deleteAttendance(String attendanceId) async {
    try {
      await Db.client
          .from(Db.tServantAttendances)
          .delete()
          .eq('id', attendanceId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  // ------------------------------------------- summary for admin list screen

  /// All unique session dates for the year, newest first (deduped across classes).
  Future<List<DateTime>> sessionDatesForYear(String yearId) async {
    try {
      final data = await Db.client
          .from(Db.tAttendanceSessions)
          .select('session_date')
          .eq('year_id', yearId)
          .order('session_date', ascending: true);
      final seen = <String>{};
      final dates = <DateTime>[];
      for (final row in rows(data)) {
        final raw = row['session_date'] as String;
        if (seen.add(raw)) {
          dates.add(DateTime.parse(raw));
        }
      }
      return dates;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// All lesson preps for sessions on a specific date (across all classes).
  Future<List<LessonPrep>> allPrepsForDate(DateTime date) async {
    try {
      final iso = '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      // Step 1: get session IDs for this date
      final sessionData = await Db.client
          .from(Db.tAttendanceSessions)
          .select('id')
          .eq('session_date', iso);
      final sessionIds =
          rows(sessionData).map((r) => r['id'] as String).toList();
      if (sessionIds.isEmpty) return [];
      // Step 2: load preps for those sessions
      final data = await Db.client
          .from(Db.tServantLessonPreps)
          .select(
            'id, servant_id, session_id, status, admin_comment, '
            'reviewed_by, reviewed_at, created_at, '
            'servant_lesson_prep_photos(id, prep_id, storage_path, created_at), '
            'attendance_sessions!inner(session_date), '
            'profiles!servant_lesson_preps_servant_id_fkey(full_name)',
          )
          .inFilter('session_id', sessionIds);
      return rows(data).map(LessonPrep.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// All servant attendance records for a specific date.
  Future<List<ServantAttendance>> servantAttendancesForDate(
      DateTime date) async {
    try {
      final iso = '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final data = await Db.client
          .from(Db.tServantAttendances)
          .select()
          .eq('date', iso);
      return rows(data).map(ServantAttendance.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Returns total attendance session count for a year (all classes).
  Future<int> sessionCountForYear(String yearId) async {
    try {
      final data = await Db.client
          .from(Db.tAttendanceSessions)
          .select('id')
          .eq('year_id', yearId);
      return rows(data).length;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Per-servant attendance + prep counts for a specific calendar month.
  Future<List<ServantMonthlyReport>> servantMonthlyReport({
    required int year,
    required int month,
  }) async {
    try {
      final from =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
      final toDate = DateTime(year, month + 1, 1)
          .subtract(const Duration(days: 1));
      final to =
          '${toDate.year.toString().padLeft(4, '0')}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';

      // Attendances for this month
      final attData = await Db.client
          .from(Db.tServantAttendances)
          .select(
            'servant_id, activity_type, '
            'profiles!servant_attendances_servant_id_fkey(full_name)',
          )
          .gte('date', from)
          .lte('date', to);

      // Sessions in this month
      final sessionData = await Db.client
          .from(Db.tAttendanceSessions)
          .select('id')
          .gte('session_date', from)
          .lte('session_date', to);
      final sessionIds =
          rows(sessionData).map((r) => r['id'] as String).toList();

      // Preps for sessions in this month
      final prepData = sessionIds.isEmpty
          ? <Map<String, dynamic>>[]
          : rows(
              await Db.client
                  .from(Db.tServantLessonPreps)
                  .select(
                    'servant_id, '
                    'profiles!servant_lesson_preps_servant_id_fkey(full_name)',
                  )
                  .inFilter('session_id', sessionIds),
            );

      final Map<String, _MonthBuilder> map = {};

      for (final row in rows(attData)) {
        final id = row['servant_id'] as String;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final name = profile?['full_name']?.toString() ?? '';
        final builder = map.putIfAbsent(id, () => _MonthBuilder(id, name));
        if (builder.servantName.isEmpty && name.isNotEmpty) {
          builder.servantName = name;
        }
        if (row['activity_type'] == 'sunday_school') {
          builder.sundaySchool++;
        } else {
          builder.servantMeeting++;
        }
      }

      for (final row in prepData) {
        final id = row['servant_id'] as String;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final name = profile?['full_name']?.toString() ?? '';
        map.putIfAbsent(id, () => _MonthBuilder(id, name));
        map[id]!.prepsCount++;
      }

      return map.values
          .map(
            (b) => ServantMonthlyReport(
              servantId: b.servantId,
              servantName: b.servantName,
              sundaySchool: b.sundaySchool,
              servantMeeting: b.servantMeeting,
              prepsCount: b.prepsCount,
            ),
          )
          .toList()
        ..sort((a, b) => a.servantName.compareTo(b.servantName));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<ServantActivitySummary>> activitySummaries() async {
    try {
      // Load ALL servant profiles so servants with zero activity still appear
      final profileData = await Db.client
          .from(Db.tProfiles)
          .select('id, full_name')
          .eq('role', AppRole.servant.wire)
          .order('full_name');

      // Load all preps grouped by servant
      final prepData = await Db.client
          .from(Db.tServantLessonPreps)
          .select(
            'servant_id, status, '
            'profiles!servant_lesson_preps_servant_id_fkey(full_name)',
          );

      // Load all attendance records
      final attendanceData = await Db.client
          .from(Db.tServantAttendances)
          .select('servant_id, activity_type');

      final prepRows = rows(prepData);
      final attendanceRows = rows(attendanceData);

      // Pre-seed map with ALL servants so those with no activity still show
      final Map<String, _SummaryBuilder> map = {};
      for (final row in rows(profileData)) {
        final id = row['id'] as String;
        final name = row['full_name']?.toString() ?? '';
        map[id] = _SummaryBuilder(id, name);
      }

      for (final row in prepRows) {
        final id = row['servant_id'] as String;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final name = profile?['full_name']?.toString() ?? '';
        map.putIfAbsent(id, () => _SummaryBuilder(id, name));
        map[id]!.totalPreps++;
        if (row['status'] == 'pending') map[id]!.pendingPreps++;
      }

      for (final row in attendanceRows) {
        final id = row['servant_id'] as String;
        map.putIfAbsent(id, () => _SummaryBuilder(id, ''));
        switch (row['activity_type'] as String?) {
          case 'sunday_school':
            map[id]!.sundaySchoolCount++;
          case 'servant_meeting':
            map[id]!.servantMeetingCount++;
          case 'mass':
            map[id]!.massCount++;
          case 'confession':
            map[id]!.confessionCount++;
        }
      }

      return map.values
          .map((b) => b.toSummary())
          .toList()
        ..sort((a, b) => a.servantName.compareTo(b.servantName));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}

class _MonthBuilder {
  _MonthBuilder(this.servantId, this.servantName);

  final String servantId;
  String servantName;
  int sundaySchool = 0;
  int servantMeeting = 0;
  int prepsCount = 0;
}

class _SummaryBuilder {
  _SummaryBuilder(this.servantId, this.servantName);

  final String servantId;
  final String servantName;
  int totalPreps = 0;
  int pendingPreps = 0;
  int sundaySchoolCount = 0;
  int servantMeetingCount = 0;
  int massCount = 0;
  int confessionCount = 0;

  ServantActivitySummary toSummary() => ServantActivitySummary(
        servantId: servantId,
        servantName: servantName,
        totalPreps: totalPreps,
        pendingPreps: pendingPreps,
        sundaySchoolCount: sundaySchoolCount,
        servantMeetingCount: servantMeetingCount,
        massCount: massCount,
        confessionCount: confessionCount,
      );
}
