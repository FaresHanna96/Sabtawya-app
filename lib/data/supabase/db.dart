import 'package:supabase_flutter/supabase_flutter.dart';

/// Single access point for the Supabase client.
///
/// Repositories go through this rather than touching `Supabase.instance`
/// directly, which keeps them easy to read and swap in tests.
class Db {
  const Db._();

  static SupabaseClient get client => Supabase.instance.client;

  static String? get userId => client.auth.currentUser?.id;

  static bool get isSignedIn => client.auth.currentSession != null;

  // Tables
  static const tProfiles = 'profiles';
  static const tServantInvites = 'servant_invites';
  static const tServantDetails = 'servant_details';
  static const tClasses = 'classes';
  static const tClassServants = 'class_servants';
  static const tChildren = 'children';
  static const tAttendanceYears = 'attendance_years';
  static const tAttendanceSessions = 'attendance_sessions';
  static const tAttendanceRecords = 'attendance_records';
  static const tActivityLog = 'activity_log';

  // Views
  static const vClassOverview = 'v_class_overview';
  static const vClassServants = 'v_class_servants';
  static const vSessionScores = 'v_session_scores';
  static const vClassSessionSummary = 'v_class_session_summary';
  static const vChildYearReport = 'v_child_year_report';
  static const vChildMonthlyReport = 'v_child_monthly_report';
  static const vClassYearScores = 'v_class_year_scores';
  static const vAdminStats = 'v_admin_stats';
  static const vChildLastActivity = 'v_child_last_activity';
  static const vChildCommitment = 'v_child_commitment';
  static const vChildAttendanceStreak = 'v_child_attendance_streak';
  static const vPendingServants = 'v_pending_servants';
  static const vChildBirthdays = 'v_child_birthdays';
  static const vServantBirthdays = 'v_servant_birthdays';

  // Tables – servant activities
  static const tServantLessonPreps = 'servant_lesson_preps';
  static const tServantLessonPrepPhotos = 'servant_lesson_prep_photos';
  static const tServantAttendances = 'servant_attendances';

  // Tables – competitions (مسابقات)
  static const tCompetitions = 'competitions';
  static const tCompetitionMarks = 'competition_marks';

  // Views – competitions
  static const vChildCompScores = 'v_child_competition_scores';

  // Tables – events (فعاليات)
  static const tEvents = 'events';
  static const tEventPayments = 'event_payments';
  static const tEventReservations = 'event_reservations';

  // Views – events
  static const vChildEventBalances = 'v_child_event_balances';

  // Tables – pastoral visits
  static const tChildVisitLogs = 'child_visit_logs';
  static const tLessons = 'lessons';
  static const tLessonExtras = 'lesson_extras';
  static const tLessonBreaks = 'lesson_breaks';

  // Storage buckets
  static const bucketChildPhotos = 'child-photos';
  static const bucketClassPatrons = 'class-patrons';
  static const bucketServantSubmissions = 'servant-submissions';
}

/// Shorthand for the repeated `List<dynamic> -> List<Map<String, dynamic>>`
/// cast that every Supabase query needs.
List<Map<String, dynamic>> rows(dynamic data) =>
    (data as List<dynamic>).map((row) => row as Map<String, dynamic>).toList();
