import '../../core/utils/app_failure.dart';
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
            .order('month_start')
            .order('child_id')
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

  /// Children below [threshold] percent for the year, lowest first.
  Future<List<ChildYearReport>> lowAttendance({
    required String yearId,
    double threshold = 60,
    int limit = 10,
  }) async {
    try {
      final data = await Db.client
          .from(Db.vChildYearReport)
          .select()
          .eq('year_id', yearId)
          .eq('child_is_active', true)
          .lt('percentage', threshold)
          .order('percentage')
          .order('child_name')
          .limit(limit);
      return rows(data).map(ChildYearReport.fromMap).toList();
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
