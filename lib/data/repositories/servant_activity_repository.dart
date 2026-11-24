import '../models/attendance.dart';
import '../models/profile.dart';
import '../models/servant_activity.dart';
import '../supabase/db.dart';
import '../services/photo_service.dart';
import '../models/parsers.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/app_failure.dart';

/// Servant self-reporting (lesson prep) and admin-recorded attendance.
class ServantActivityRepository {
  const ServantActivityRepository();

  /// A prep with its photos, its Saturday and class, and who sent it.
  static const _prepSelect =
      'id, servant_id, session_id, status, admin_comment, '
      'reviewed_by, reviewed_at, created_at, shared_at, '
      'servant_lesson_prep_photos(id, prep_id, storage_path, created_at), '
      'attendance_sessions!inner(session_date, classes(name)), '
      'profiles!servant_lesson_preps_servant_id_fkey(full_name)';

  // ----------------------------------------------------------------- servant

  /// The servant's own lesson prep for [sessionId], or null if not yet submitted.
  Future<LessonPrep?> lessonPrepForSession(String sessionId) async {
    try {
      final data = await Db.client
          .from(Db.tServantLessonPreps)
          .select(_prepSelect)
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

  /// Saves several uploaded files on [prepId] in one request (it was one
  /// request per photo).
  Future<void> addPrepPhotos({
    required String prepId,
    required List<String> storagePaths,
  }) async {
    if (storagePaths.isEmpty) return;
    try {
      await Db.client.from(Db.tServantLessonPrepPhotos).insert([
        for (final path in storagePaths)
          <String, dynamic>{'prep_id': prepId, 'storage_path': path},
      ]);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Removes one file from the servant's own prep (the row, then the file).
  Future<void> removePrepPhoto(LessonPrepPhoto photo) async {
    try {
      await Db.client
          .from(Db.tServantLessonPrepPhotos)
          .delete()
          .eq('id', photo.id);
    } catch (e) {
      throw AppFailure.from(e);
    }
    // The row is what the screens read; a file left behind is harmless.
    try {
      await PhotoService.remove(
        bucket: Db.bucketServantSubmissions,
        path: photo.storagePath,
      );
    } catch (_) {}
  }

  /// Sends the servant's own commented prep back for review.
  Future<void> resubmitPrep(String prepId) async {
    try {
      await Db.client.rpc('resubmit_prep', params: {'p_prep_id': prepId});
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The servant's own preps for the list in «تحضيراتي»: the Saturday, the
  /// status and whether it was shared, without the files (a prep's page
  /// loads those).
  Future<List<LessonPrep>> myPrepsSummary() async {
    try {
      final data = await Db.client
          .from(Db.tServantLessonPreps)
          .select('id, servant_id, session_id, status, admin_comment, '
              'reviewed_at, created_at, shared_at, '
              'attendance_sessions!inner(session_date, classes(name))')
          .eq('servant_id', Db.userId!)
          // A Saturday marked إجازة / نشاط ترفيهي counts for nothing.
          .eq('attendance_sessions.is_break', false)
          .order('created_at', ascending: false);
      return rows(data).map(LessonPrep.fromMap).toList();
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
          .inFilter('class_id', classIds)
          // No lesson, no prep and nothing to count.
          .eq('is_break', false);
      if (yearId != null) query = query.eq('year_id', yearId);
      final data = await query.order('session_date', ascending: true);
      return rows(data).map(AttendanceSession.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// One lesson prep by its id, or null when it does not exist or is not
  /// visible to the signed-in person (row level security).
  Future<LessonPrep?> prepById(String id) async {
    try {
      final data = await Db.client
          .from(Db.tServantLessonPreps)
          .select(_prepSelect)
          .eq('id', id)
          .maybeSingle();
      return data == null ? null : LessonPrep.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// All lesson preps for the signed-in servant, newest first.
  Future<List<LessonPrep>> myLessonPreps() async {
    try {
      final data = await Db.client
          .from(Db.tServantLessonPreps)
          .select(_prepSelect)
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
          .select(_prepSelect)
          .eq('servant_id', servantId)
          .eq('attendance_sessions.is_break', false)
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
          .select(_prepSelect)
          .eq('status', 'pending')
          .order('created_at', ascending: true);
      return rows(data).map(LessonPrep.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The latest [limit] preps of every status, newest first («التحضيرات»).
  Future<List<LessonPrep>> recentPreps({int limit = 200}) async {
    try {
      final data = await Db.client
          .from(Db.tServantLessonPreps)
          .select(_prepSelect)
          .eq('attendance_sessions.is_break', false)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows(data).map(LessonPrep.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// How many preps wait for review: ids only, for a badge.
  Future<int> pendingPrepsCount() async {
    try {
      final data = await Db.client
          .from(Db.tServantLessonPreps)
          .select('id')
          .eq('status', 'pending');
      return rows(data).length;
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
      await Db.client.from(Db.tServantLessonPreps).update(<String, dynamic>{
        'status': status,
        'admin_comment': comment,
        'reviewed_by': Db.userId,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', prepId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  // ------------------------------------------------- attendance (admin only)

  /// Attendance records for [servantId] filtered by [activityType], newest
  /// first. Give [from] / [to] (inclusive) to keep one year only: the
  /// percentages divide by that year's Saturdays, so older years must not
  /// be counted in.
  Future<List<ServantAttendance>> attendancesForServant(
    String servantId,
    String activityType, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var query = Db.client
          .from(Db.tServantAttendances)
          .select()
          .eq('servant_id', servantId)
          .eq('activity_type', activityType);
      if (from != null) query = query.gte('date', isoDate(from));
      if (to != null) query = query.lte('date', isoDate(to));
      final data = await query.order('date', ascending: false);
      return rows(data).map(ServantAttendance.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// How many times [servantId] was marked in each activity between [from]
  /// and [to] (inclusive), in one query: activity type -> count.
  Future<Map<String, int>> activityCounts({
    required String servantId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final data = await Db.client
          .from(Db.tServantAttendances)
          .select('activity_type')
          .eq('servant_id', servantId)
          .gte('date', isoDate(from))
          .lte('date', isoDate(to));
      return countByType(rows(data));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Every mark of [servantId] between [from] and [to] (inclusive), oldest
  /// first: for "حضوري" (which Saturdays) and the counts, in one query.
  Future<List<ServantAttendance>> marksForServant({
    required String servantId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final data = await Db.client
          .from(Db.tServantAttendances)
          .select('id, servant_id, activity_type, date, recorded_by')
          .eq('servant_id', servantId)
          .gte('date', isoDate(from))
          .lte('date', isoDate(to))
          .order('date');
      return rows(data).map(ServantAttendance.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Counts rows per `activity_type`.
  static Map<String, int> countByType(Iterable<Map<String, dynamic>> rows) {
    final out = <String, int>{};
    for (final r in rows) {
      final type = r['activity_type']?.toString();
      if (type == null || type.isEmpty) continue;
      out[type] = (out[type] ?? 0) + 1;
    }
    return out;
  }

  /// yyyy-MM-dd of [d]'s calendar day (no time zone shift).
  static String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Marks [servantId] present in [activityType] on [date] and returns the
  /// new row, so the caller can show it without reloading the whole day.
  Future<ServantAttendance> recordAttendance({
    required String servantId,
    required String activityType,
    required DateTime date,
  }) async {
    try {
      final data = await Db.client
          .from(Db.tServantAttendances)
          .insert(<String, dynamic>{
            'servant_id': servantId,
            'activity_type': activityType,
            'date': isoDate(date),
            'recorded_by': Db.userId,
          })
          .select()
          .single();
      return ServantAttendance.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The substitutes recorded on [date] (empty where the table is missing).
  Future<List<ServantSubstitute>> substitutesOn(DateTime date) async {
    try {
      final data = await Db.client
          .from(Db.tServantSubstitutes)
          .select()
          .eq('date', isoDate(date));
      return rows(data).map(ServantSubstitute.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// [servantId]'s substitute records either way (covered or was covered)
  /// between [from] and [to], newest first.
  Future<List<ServantSubstitute>> substitutesForServant(
    String servantId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var query = Db.client
          .from(Db.tServantSubstitutes)
          .select()
          .or('absent_servant_id.eq.$servantId,'
              'substitute_servant_id.eq.$servantId');
      if (from != null) query = query.gte('date', isoDate(from));
      if (to != null) query = query.lte('date', isoDate(to));
      final data = await query.order('date', ascending: false);
      return rows(data).map(ServantSubstitute.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Records that [substituteServantId] covered [absentServantId]'s class
  /// on [date], and credits them with «خدمة», in one call.
  Future<void> recordSubstitute({
    required DateTime date,
    required String classId,
    required String absentServantId,
    required String substituteServantId,
  }) async {
    try {
      await Db.client.rpc('record_substitute', params: {
        'p_date': isoDate(date),
        'p_class_id': classId,
        'p_absent_servant_id': absentServantId,
        'p_substitute_servant_id': substituteServantId,
      });
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Undoes a substitute record and the «خدمة» mark it gave.
  Future<void> removeSubstitute(String id) async {
    try {
      await Db.client.rpc('remove_substitute', params: {'p_id': id});
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Marks every one of [servantIds] present in [activityType] on [date] in
  /// one request, and returns the new rows («الكل حضروا»).
  Future<List<ServantAttendance>> recordAttendanceMany({
    required List<String> servantIds,
    required String activityType,
    required DateTime date,
  }) async {
    if (servantIds.isEmpty) return const [];
    try {
      final data = await Db.client
          .from(Db.tServantAttendances)
          .insert([
            for (final id in servantIds)
              <String, dynamic>{
                'servant_id': id,
                'activity_type': activityType,
                'date': isoDate(date),
                'recorded_by': Db.userId,
              },
          ])
          .select();
      return rows(data).map(ServantAttendance.fromMap).toList();
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
      final data = await _heldSessionRows(yearId, orderAsc: true);
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

  /// The session dates of [yearId] that count for the servants' attendance.
  /// A holiday counts for nothing; a نشاط ترفيهي counts (but has no prep: see
  /// activityDatesForYear). A database from before `servants_off` (migration
  /// 20261124008) falls back to «every day with a lesson».
  Future<dynamic> _heldSessionRows(
    String yearId, {
    bool orderAsc = false,
    String? upTo,
  }) async {
    dynamic build(bool legacy) {
      var q = Db.client
          .from(Db.tAttendanceSessions)
          .select('session_date')
          .eq('year_id', yearId)
          .eq(legacy ? 'is_break' : 'servants_off', false);
      if (upTo != null) q = q.lte('session_date', upTo);
      return orderAsc ? q.order('session_date', ascending: true) : q;
    }

    try {
      return await build(false);
    } catch (_) {
      return await build(true);
    }
  }

  /// The نشاط ترفيهي Saturdays of [yearId]: servant attendance counts, but
  /// there is no lesson, so no prep is expected or counted.
  Future<List<DateTime>> activityDatesForYear(String yearId) async {
    try {
      final data = await Db.client
          .from(Db.tAttendanceSessions)
          .select('session_date')
          .eq('year_id', yearId)
          .eq('is_break', true)
          .eq('servants_off', false)
          .order('session_date', ascending: true);
      return {
        for (final row in rows(data)) row['session_date'] as String,
      }.map(DateTime.parse).toList();
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
          .select(_prepSelect)
          .inFilter('session_id', sessionIds);
      return rows(data).map(LessonPrep.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The classes that have a lesson prep for their session on [date], any
  /// status. Preps are readable by the admin (all) and their own servant, so
  /// for anyone else this is not the whole picture: the class cards ask it
  /// for the admin only.
  Future<Set<String>> classesWithPrepOn(DateTime date) async {
    try {
      final sessions = rows(await Db.client
          .from(Db.tAttendanceSessions)
          .select('id, class_id')
          .eq('session_date', AppDateUtils.toIsoDate(date)));
      if (sessions.isEmpty) return const {};
      final classOf = {
        for (final s in sessions) asText(s['id']): asText(s['class_id']),
      };
      final preps = rows(await Db.client
          .from(Db.tServantLessonPreps)
          .select('session_id')
          .inFilter('session_id', classOf.keys.toList()));
      return {
        for (final p in preps)
          if (classOf[asText(p['session_id'])] case final classId?) classId,
      };
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Every servant mark between [from] and [to] (inclusive): the admin gets
  /// all servants, a servant their own (row level security), or only
  /// [servantId]'s.
  Future<List<ServantAttendance>> attendancesBetween({
    required DateTime from,
    required DateTime to,
    String? servantId,
  }) async {
    try {
      var query = Db.client
          .from(Db.tServantAttendances)
          .select()
          .gte('date', AppDateUtils.toIsoDate(from))
          .lte('date', AppDateUtils.toIsoDate(to));
      if (servantId != null) query = query.eq('servant_id', servantId);
      final data = await query;
      return rows(data).map(ServantAttendance.fromMap).toList();
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
      final data =
          await Db.client.from(Db.tServantAttendances).select().eq('date', iso);
      return rows(data).map(ServantAttendance.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// How many Saturdays of [yearId] were already held: one per date, however
  /// many classes met that day. A servant is marked once per Saturday, so
  /// this is the base of every servant percentage.
  Future<int> sessionCountForYear(String yearId) async {
    try {
      // Only sessions already held, so percentages are "so far".
      final data =
          await _heldSessionRows(yearId, upTo: isoDate(DateTime.now()));
      return distinctDates(rows(data));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The number of different `session_date` values in [rows].
  static int distinctDates(Iterable<Map<String, dynamic>> rows) =>
      {for (final r in rows) r['session_date']?.toString()}
          .whereType<String>()
          .length;

  /// Per-servant attendance + prep counts for a specific calendar month.
  Future<List<ServantMonthlyReport>> servantMonthlyReport({
    required int year,
    required int month,
  }) async {
    try {
      final from =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
      final toDate =
          DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
      final to =
          '${toDate.year.toString().padLeft(4, '0')}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';

      // Attendances for this month
      final attData = await Db.client
          .from(Db.tServantAttendances)
          .select(
            'servant_id, activity_type, date, '
            'profiles!servant_attendances_servant_id_fkey(full_name)',
          )
          .gte('date', from)
          .lte('date', to);

      // A holiday counts for nothing. A نشاط ترفيهي counts for the four
      // activities, but there is no prep that day.
      final breakRows = rows(await Db.client
          .from(Db.tLessonBreaks)
          .select('break_date, kind')
          .gte('break_date', from)
          .lte('break_date', to));
      final breakDays = {
        for (final b in breakRows) b['break_date']?.toString(),
      };
      final holidays = {
        for (final b in breakRows)
          if (b['kind'] != 'activity') b['break_date']?.toString(),
      };

      // Sessions in this month
      final sessionData = await Db.client
          .from(Db.tAttendanceSessions)
          .select('id')
          .eq('is_break', false)
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
                    'servant_id, attendance_sessions!inner(session_date), '
                    'profiles!servant_lesson_preps_servant_id_fkey(full_name)',
                  )
                  .inFilter('session_id', sessionIds),
            );

      final Map<String, _MonthBuilder> map = {};

      for (final row in rows(attData)) {
        final day = row['date']?.toString();
        if (holidays.contains(day)) continue;
        if (row['activity_type'] == 'lesson_prep' && breakDays.contains(day)) {
          continue;
        }
        final id = row['servant_id'] as String;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final name = profile?['full_name']?.toString() ?? '';
        final builder = map.putIfAbsent(id, () => _MonthBuilder(id, name));
        if (builder.servantName.isEmpty && name.isNotEmpty) {
          builder.servantName = name;
        }
        switch (row['activity_type']) {
          case 'sunday_school':
            builder.sundaySchool++;
          case 'servant_meeting':
            builder.servantMeeting++;
          case 'mass':
            builder.mass++;
          case 'confession':
            builder.confession++;
        }
      }

      // A Saturday has a prep when the servant uploaded one or the admin
      // ticked «تحضير الدرس» for them: counted once per Saturday.
      final prepDays = <String, Set<String>>{};
      for (final row in prepData) {
        final id = row['servant_id'] as String;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final name = profile?['full_name']?.toString() ?? '';
        map.putIfAbsent(id, () => _MonthBuilder(id, name));
        final session = row['attendance_sessions'] as Map<String, dynamic>?;
        (prepDays[id] ??= {}).add(session?['session_date']?.toString() ?? '');
      }
      for (final row in rows(attData)) {
        if (row['activity_type'] != 'lesson_prep') continue;
        if (breakDays.contains(row['date']?.toString())) continue;
        final id = row['servant_id'] as String;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final name = profile?['full_name']?.toString() ?? '';
        map.putIfAbsent(id, () => _MonthBuilder(id, name));
        (prepDays[id] ??= {}).add(row['date']?.toString() ?? '');
      }
      for (final e in prepDays.entries) {
        map[e.key]!.prepsCount = e.value.length;
      }

      return map.values
          .map(
            (b) => ServantMonthlyReport(
              servantId: b.servantId,
              servantName: b.servantName,
              sundaySchool: b.sundaySchool,
              servantMeeting: b.servantMeeting,
              prepsCount: b.prepsCount,
              mass: b.mass,
              confession: b.confession,
            ),
          )
          .toList()
        ..sort((a, b) => a.servantName.compareTo(b.servantName));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Every servant with their activity counts. Give [from] / [to] to count
  /// one year only (attendance by its date, preps by their Saturday), which
  /// the percentages need: they divide by that year's Saturdays.
  Future<List<ServantActivitySummary>> activitySummaries({
    DateTime? from,
    DateTime? to,
  }) async {
    // Added up in the database (servant_activity_summary) when it can be;
    // the rows are only downloaded and added up here as a fallback (a
    // database without the function yet).
    if (from != null && to != null) {
      try {
        final data = await Db.client.rpc('servant_activity_summary', params: {
          'p_from': isoDate(from),
          'p_to': isoDate(to),
        });
        return rows(data).map(ServantActivitySummary.fromMap).toList();
      } catch (_) {
        // Fall through to the rows.
      }
    }
    return _summariesFromRows(from: from, to: to);
  }

  Future<List<ServantActivitySummary>> _summariesFromRows({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      // The three reads do not depend on each other.
      var prepQuery = Db.client.from(Db.tServantLessonPreps).select(
            'servant_id, status, '
            'attendance_sessions!inner(session_date), '
            'profiles!servant_lesson_preps_servant_id_fkey(full_name)',
          ).eq('attendance_sessions.is_break', false);
      if (from != null) {
        prepQuery =
            prepQuery.gte('attendance_sessions.session_date', isoDate(from));
      }
      if (to != null) {
        prepQuery =
            prepQuery.lte('attendance_sessions.session_date', isoDate(to));
      }
      var attendanceQuery = Db.client
          .from(Db.tServantAttendances)
          .select('servant_id, activity_type, date');
      if (from != null) {
        attendanceQuery = attendanceQuery.gte('date', isoDate(from));
      }
      if (to != null) attendanceQuery = attendanceQuery.lte('date', isoDate(to));

      // A holiday counts for nothing, as in the database function.
      final holidayQuery =
          Db.client.from(Db.tLessonBreaks).select('break_date, kind');

      final (profileData, prepData, attendanceData, breakData) = await (
        // ALL servant profiles, so servants with zero activity still appear.
        Db.client.from(Db.tProfiles).select('id, full_name, role').order(
              'full_name',
            ),
        prepQuery,
        attendanceQuery,
        holidayQuery.catchError((Object _) => <dynamic>[]),
      ).wait;
      final holidays = {
        for (final b in rows(breakData))
          if (b['kind'] != 'activity') b['break_date']?.toString(),
      };

      final prepRows = rows(prepData);
      final attendanceRows = rows(attendanceData);

      // Pre-seed map with ALL servants so those with no activity still show
      final Map<String, _SummaryBuilder> map = {};
      final names = <String, String>{};
      for (final row in rows(profileData)) {
        final id = row['id'] as String;
        final name = row['full_name']?.toString() ?? '';
        names[id] = name;
        // خادم عام takes part in the same activities as a class servant.
        final role = row['role']?.toString();
        if (role == AppRole.servant.wire ||
            role == AppRole.generalServant.wire) {
          map[id] = _SummaryBuilder(id, name);
        }
      }

      for (final row in prepRows) {
        final id = row['servant_id'] as String;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final name = profile?['full_name']?.toString() ?? names[id] ?? '';
        map.putIfAbsent(id, () => _SummaryBuilder(id, name));
        map[id]!.totalPreps++;
        if (row['status'] == 'pending') map[id]!.pendingPreps++;
      }

      for (final row in attendanceRows) {
        if (holidays.contains(row['date']?.toString())) continue;
        final id = row['servant_id'] as String;
        map.putIfAbsent(id, () => _SummaryBuilder(id, names[id] ?? ''));
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

      return map.values.map((b) => b.toSummary()).toList()
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
  int mass = 0;
  int confession = 0;
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
