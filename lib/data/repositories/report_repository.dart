import '../../core/utils/app_failure.dart';
import '../models/class_health.dart';
import '../models/parsers.dart';
import '../models/reports.dart';
import '../supabase/db.dart';

/// Reads the reporting views. All aggregation happens in Postgres, so the app
/// never recomputes a score it could get wrong.
class ReportRepository {
  const ReportRepository();

  Future<AdminStats> adminStats() async {
    try {
      final data =
          await Db.client.from(Db.vAdminStats).select().limit(1).maybeSingle();
      return data == null ? AdminStats.empty : AdminStats.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<ClassYearScore>> classScores(String yearId) async {
    try {
      final data = await Db.client
          .from(Db.vClassYearScores)
          .select()
          .eq('year_id', yearId)
          .order('class_name');
      return rows(data).map(ClassYearScore.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// أمين الخدمة only: how each active class is doing this year.
  Future<List<ClassHealth>> classHealth(String yearId) async {
    try {
      final data =
          await Db.client.rpc('class_health', params: {'p_year': yearId});
      return rows(data).map(ClassHealth.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<ChildYearReport>> childYearReports({
    required String yearId,
    String? classId,
    bool onlyActive = true,
  }) async {
    try {
      var query =
          Db.client.from(Db.vChildYearReport).select().eq('year_id', yearId);
      if (classId != null) query = query.eq('class_id', classId);
      if (onlyActive) query = query.eq('child_is_active', true);
      final data = await query.order('child_name');
      return rows(data).map(ChildYearReport.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<ChildYearReport?> childYear({
    required String childId,
    required String yearId,
  }) async {
    try {
      final data = await Db.client
          .from(Db.vChildYearReport)
          .select()
          .eq('child_id', childId)
          .eq('year_id', yearId)
          .maybeSingle();
      return data == null ? null : ChildYearReport.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<ChildMonthlyReport>> childMonthly({
    required String yearId,
    String? childId,
    String? classId,
    bool onlyActive = true,
  }) async {
    try {
      var query =
          Db.client.from(Db.vChildMonthlyReport).select().eq('year_id', yearId);
      if (childId != null) query = query.eq('child_id', childId);
      if (classId != null) query = query.eq('class_id', classId);
      if (onlyActive) query = query.eq('child_is_active', true);
      // A year of monthly rows is 13 months x every child, well over the
      // 1000 rows one response may hold, so read it page by page. Without
      // this the later months silently went missing from the reports.
      const page = 1000;
      final all = <ChildMonthlyReport>[];
      for (var from = 0;; from += page) {
        final data = await query
            .order('month_start', ascending: true)
            .order('child_id', ascending: true)
            .range(from, from + page - 1);
        final batch = rows(data);
        all.addAll(batch.map(ChildMonthlyReport.fromMap));
        if (batch.length < page) break;
      }
      return all;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Every child's score at each Saturday between [from] and [to] (both
  /// inclusive, either may be open), so a report over a date range counts
  /// exactly the Saturdays inside it. Only Saturdays whose attendance was
  /// taken have records, so the rest never count against anybody.
  Future<List<SessionScore>> sessionScores({
    required String yearId,
    String? classId,
    DateTime? from,
    DateTime? to,
  }) async {
    String iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    try {
      var query = Db.client
          .from(Db.tAttendanceRecords)
          .select(
            'child_id, score, '
            'attendance_sessions!inner(session_date, class_id, year_id), '
            'children!inner(full_name, is_active, classes(name))',
          )
          .eq('attendance_sessions.year_id', yearId)
          .eq('children.is_active', true);
      if (classId != null) {
        query = query.eq('attendance_sessions.class_id', classId);
      }
      if (from != null) {
        query = query.gte('attendance_sessions.session_date', iso(from));
      }
      if (to != null) {
        query = query.lte('attendance_sessions.session_date', iso(to));
      }
      // Paged: a year of Saturdays for every child is well over 1000 rows.
      const page = 1000;
      final all = <SessionScore>[];
      for (var start = 0;; start += page) {
        final data = await query.order('id').range(start, start + page - 1);
        final batch = rows(data);
        all.addAll(batch.map(SessionScore.fromMap));
        if (batch.length < page) break;
      }
      return all;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Activity rates (Sunday school, vespers, mass, confession) of the active
  /// children for a year, against the Saturdays held so far.
  Future<List<ChildActivityRate>> activityRates({
    required String yearId,
    String? classId,
  }) async {
    try {
      var query = Db.client
          .from(Db.vChildActivityRates)
          .select()
          .eq('year_id', yearId)
          .eq('child_is_active', true);
      if (classId != null) query = query.eq('class_id', classId);
      final data = await query.order('child_name', ascending: true);
      return rows(data).map(ChildActivityRate.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// How far back the weekly chart looks: 12 Saturdays, enough for the ten
  /// it shows and the one before them.
  static const _weeksBack = Duration(days: 84);

  static String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Saturday by Saturday over the last 12 weeks (up to today, oldest first):
  /// who came across every class the caller can see, out of their active
  /// children, each class kept apart. A Saturday nobody recorded stays in
  /// (the card shows the gap); a week with no lesson is marked as a break.
  Future<List<WeeklyAttendance>> weeklyAttendance(String yearId) async {
    try {
      final today = DateTime.now();
      final iso = _iso(today);
      final from = _iso(today.subtract(_weeksBack));
      final results = await Future.wait<dynamic>([
        Db.client
            .from(Db.vClassSessionSummary)
            .select('session_date, class_id, present_count, active_children, '
                'recorded_count')
            .eq('year_id', yearId)
            .gte('session_date', from)
            .lte('session_date', iso)
            .order('session_date', ascending: true),
        Db.client
            .from(Db.tLessonBreaks)
            .select('break_date')
            .gte('break_date', from)
            .lte('break_date', iso),
      ]);
      final breaks = {
        for (final r in rows(results[1])) asText(r['break_date'])
      };
      final byDate = <String, List<ClassWeek>>{};
      for (final r in rows(results[0])) {
        (byDate[asText(r['session_date'])] ??= []).add(ClassWeek(
          classId: asText(r['class_id']),
          present: asInt(r['present_count']),
          children: asInt(r['active_children']),
          // A class whose attendance was not taken does not count as absent.
          recorded: asInt(r['recorded_count']) > 0,
        ));
      }
      return [
        for (final MapEntry(key: d, value: classes) in byDate.entries)
          WeeklyAttendance(
            date: DateTime.parse(d),
            present: classes
                .where((c) => c.recorded)
                .fold(0, (s, c) => s + c.present),
            children: classes
                .where((c) => c.recorded)
                .fold(0, (s, c) => s + c.children),
            missingClassIds: [
              for (final c in classes)
                if (!c.recorded) c.classId,
            ],
            perClass: classes,
            isBreak: breaks.contains(d),
            isToday: d == iso,
          ),
      ];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// For the Saturday [date]: each class that meets that day (through row
  /// level security, the caller's classes) and whether its attendance was
  /// taken. A class with no session that day is not in the map.
  Future<Map<String, bool>> recordedOn({
    required String yearId,
    required DateTime date,
  }) async {
    try {
      final data = await Db.client
          .from(Db.vClassSessionSummary)
          .select('class_id, recorded_count')
          .eq('year_id', yearId)
          .eq('session_date', _iso(date));
      return {
        for (final r in rows(data))
          asText(r['class_id']): asInt(r['recorded_count']) > 0,
      };
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// For the Saturday [date]: each class that meets that day (through row
  /// level security, the caller's classes) with who came, out of its active
  /// children, and whether it was recorded. The same read as [recordedOn],
  /// with the numbers the class cards show.
  Future<Map<String, ClassWeek>> classWeekOn({
    required String yearId,
    required DateTime date,
  }) async {
    try {
      final data = await Db.client
          .from(Db.vClassSessionSummary)
          .select('class_id, present_count, active_children, recorded_count')
          .eq('year_id', yearId)
          .eq('session_date', _iso(date));
      return {
        for (final r in rows(data))
          asText(r['class_id']): ClassWeek(
            classId: asText(r['class_id']),
            present: asInt(r['present_count']),
            children: asInt(r['active_children']),
            recorded: asInt(r['recorded_count']) > 0,
          ),
      };
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The whole service's attendance % per Saturday over the same 12 weeks,
  /// for a servant to compare their class with. Totals only (a database
  /// function), so a servant learns nothing about another class. Empty when
  /// it cannot be read: the comparison is then simply not shown.
  Future<Map<DateTime, double>> serviceWeeklyAttendance(String yearId) async {
    try {
      final from = _iso(DateTime.now().subtract(_weeksBack));
      final data = await Db.client.rpc(
        'service_weekly_attendance',
        params: {'p_year': yearId, 'p_from': from},
      );
      return {
        for (final r in rows(data))
          if (asInt(r['children']) > 0)
            DateTime.parse(asText(r['session_date'])):
                asInt(r['present']) / asInt(r['children']) * 100,
      };
    } catch (_) {
      return const {};
    }
  }

  /// When [childId] last did each of the four activities.
  Future<ChildLastActivity?> lastActivity(String childId) async {
    try {
      final data = await Db.client
          .from(Db.vChildLastActivity)
          .select()
          .eq('child_id', childId)
          .maybeSingle();
      return data == null ? null : ChildLastActivity.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Children ranked by points earned so far, highest first: المميزون.
  Future<List<ChildCommitment>> topChildren({
    required String yearId,
    String? classId,
    int limit = 20,
  }) async {
    try {
      var query =
          Db.client.from(Db.vChildCommitment).select().eq('year_id', yearId);
      if (classId != null) query = query.eq('class_id', classId);
      final data = await query
          .order('points', ascending: false)
          .order('current_streak', ascending: false)
          .limit(limit);
      return rows(data).map(ChildCommitment.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Children with a run of absences or a run of attendance worth noticing,
  /// for the current year. Row level security limits it to the caller's
  /// classes, so a servant only ever sees their own children.
  Future<List<ChildStreak>> streaks({
    required String yearId,
    String? classId,
    int minAbsent = 2,
    int minPresent = 3,
  }) async {
    try {
      var query = Db.client
          .from(Db.vChildAttendanceStreak)
          .select()
          .eq('year_id', yearId)
          .or('absent_streak.gte.$minAbsent,present_streak.gte.$minPresent');
      if (classId != null) query = query.eq('class_id', classId);
      final data = await query;
      return rows(data).map(ChildStreak.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Children whose attendance fell by 25 points or more over the last four
  /// Saturdays compared with the four before, biggest drop first. Row level
  /// security limits it to the caller's classes.
  Future<List<ChildTrend>> decliningChildren({required String yearId}) async {
    try {
      final data = await Db.client
          .from(Db.vChildAttendanceTrend)
          .select()
          .eq('year_id', yearId)
          .eq('is_declining', true);
      final list = rows(data).map(ChildTrend.fromMap).toList()
        ..sort((a, b) => b.drop.compareTo(a.drop));
      return list;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Children who keep showing up: الملتزمون.
  ///
  /// Ordered by the unbroken run of Saturdays first and the overall rate
  /// second, so steady attendance outranks a child who scored highly once.
  Future<List<ChildCommitment>> committedChildren({
    required String yearId,
    String? classId,
    double minRate = 80,
    int limit = 20,
  }) async {
    try {
      var query =
          Db.client.from(Db.vChildCommitment).select().eq('year_id', yearId);
      if (classId != null) query = query.eq('class_id', classId);
      final data = await query
          .gte('attendance_percentage', minRate)
          .order('current_streak', ascending: false)
          .order('attendance_percentage', ascending: false)
          .order('points', ascending: false)
          .limit(limit);
      return rows(data).map(ChildCommitment.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// One page of the activity log, newest first, narrowed by who did it, the
  /// kind of record, the child it is about and the start of the period.
  Future<List<ActivityLogEntry>> activityPage({
    int offset = 0,
    int limit = 50,
    String? actorId,
    String? entity,
    String? childId,
    DateTime? from,
  }) async {
    try {
      var query = Db.client.from(Db.tActivityLog).select();
      if (actorId != null) query = query.eq('actor_id', actorId);
      if (entity != null) query = query.eq('entity', entity);
      // A child's own entries carry its id as the row; attendance entries
      // (from the day the log started naming children) carry it in the details.
      if (childId != null) {
        query =
            query.or('entity_id.eq.$childId,details->>child_id.eq.$childId');
      }
      if (from != null) {
        query = query.gte('created_at', from.toUtc().toIso8601String());
      }
      final data = await query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + limit - 1);
      return rows(data).map(ActivityLogEntry.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<ActivityLogEntry>> recentActivity({int limit = 15}) async {
    try {
      final data = await Db.client
          .from(Db.tActivityLog)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return rows(data).map(ActivityLogEntry.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
