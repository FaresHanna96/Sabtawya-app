import '../../core/utils/app_failure.dart';
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

  /// Saturday by Saturday (up to today, oldest first): who came across every
  /// class the caller can see, out of their active children. One query.
  Future<List<WeeklyAttendance>> weeklyAttendance(String yearId) async {
    try {
      final today = DateTime.now();
      final iso = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final data = await Db.client
          .from(Db.vClassSessionSummary)
          .select('session_date, class_id, present_count, active_children, '
              'recorded_count')
          .eq('year_id', yearId)
          .lte('session_date', iso)
          .order('session_date', ascending: true);
      final byDate = <String, List<int>>{};
      final missing = <String, List<String>>{};
      for (final r in rows(data)) {
        final d = asText(r['session_date']);
        // A class whose attendance was not taken does not count as absent;
        // it is listed as not recorded instead.
        if (asInt(r['recorded_count']) == 0) {
          (missing[d] ??= []).add(asText(r['class_id']));
          continue;
        }
        final acc = byDate[d] ??= [0, 0];
        acc[0] += asInt(r['present_count']);
        acc[1] += asInt(r['active_children']);
      }
      // Saturdays where nobody recorded yet are left out altogether.
      return [
        for (final e in byDate.entries)
          WeeklyAttendance(
            date: DateTime.parse(e.key),
            present: e.value[0],
            children: e.value[1],
            missingClassIds: missing[e.key] ?? const [],
          ),
      ];
    } catch (e) {
      throw AppFailure.from(e);
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
