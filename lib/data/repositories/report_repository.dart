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
      var query = Db.client
          .from(Db.vChildMonthlyReport)
          .select()
          .eq('year_id', yearId);
      if (childId != null) query = query.eq('child_id', childId);
      if (classId != null) query = query.eq('class_id', classId);
      if (onlyActive) query = query.eq('child_is_active', true);
      final data = await query.order('month_start');
      return rows(data).map(ChildMonthlyReport.fromMap).toList();
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
