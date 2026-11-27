import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/services/connectivity_service.dart';

/// Single access point for the Supabase client.
///
/// Repositories go through this rather than touching `Supabase.instance`
/// directly, which keeps them easy to read and swap in tests.
class Db {
  const Db._();

  static SupabaseClient get client => testClient ?? Supabase.instance.client;

  @visibleForTesting
  static SupabaseClient? testClient;

  /// The HTTP layer under the client, which keeps reads and queues writes.
  static http.Client? offlineHttp;

  /// Rows of a table or view. Every repository reads and writes through this.
  ///
  /// The library refuses any request, before it reaches [offlineHttp], once the
  /// sign-in has expired and cannot be renewed. Offline that would hide the
  /// kept answers and lose saves, so in exactly that case the request goes to
  /// [offlineHttp] with the stored token: a queued write is sent later with a
  /// fresh one.
  static PostgrestQueryBuilder<void> from(String table) {
    final session = client.auth.currentSession;
    final inner = offlineHttp;
    if (session == null ||
        inner == null ||
        ConnectivityService.instance.isOnline ||
        !_expired(session)) {
      return client.from(table);
    }
    return PostgrestClient(
      client.rest.url,
      headers: <String, String>{
        ...client.rest.headers,
        'apikey': AppConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${session.accessToken}',
      },
      schema: 'public',
      httpClient: inner,
      retryEnabled: false,
    ).from(table);
  }

  static bool _expired(Session session) {
    final at = session.expiresAt;
    return at != null && DateTime.now().millisecondsSinceEpoch >= at * 1000;
  }

  static String? get userId => client.auth.currentUser?.id;

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
  static const vChildActivityRates = 'v_child_activity_rates';
  static const vChildMonthlyReport = 'v_child_monthly_report';
  static const vClassYearScores = 'v_class_year_scores';
  static const vAdminStats = 'v_admin_stats';
  static const vChildLastActivity = 'v_child_last_activity';
  static const vChildAttendanceStreak = 'v_child_attendance_streak';
  static const vChildAttendanceTrend = 'v_child_attendance_trend';
  static const vPendingServants = 'v_pending_servants';
  static const vServantBirthdays = 'v_servant_birthdays';

  // Tables – servant activities
  static const tServantLessonPreps = 'servant_lesson_preps';
  static const tServantLessonPrepPhotos = 'servant_lesson_prep_photos';
  static const tServantAttendances = 'servant_attendances';
  static const tServantSubstitutes = 'servant_substitutes';

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
  static const tChildPrivateNotes = 'child_private_notes';
  static const tLessons = 'lessons';
  static const tLessonExtras = 'lesson_extras';
  static const tLessonBreaks = 'lesson_breaks';
  static const tLessonMaterials = 'lesson_materials';
  static const tMessageTemplates = 'message_templates';
  static const tAnnouncements = 'announcements';

  // Storage buckets
  static const bucketChildPhotos = 'child-photos';
  static const bucketClassPatrons = 'class-patrons';
  static const bucketServantSubmissions = 'servant-submissions';
  static const bucketLessonMaterials = 'lesson-materials';
}

/// Every row of a query: the server returns at most 1000 at once, silently.
/// [page] asks for rows `from` to `to` and must order by something unique, or
/// a row can come twice or be missed between two pages.
Future<List<Map<String, dynamic>>> allRows(
  Future<dynamic> Function(int from, int to) page, {
  int size = 1000,
}) async {
  final all = <Map<String, dynamic>>[];
  for (var from = 0;; from += size) {
    final batch = rows(await page(from, from + size - 1));
    all.addAll(batch);
    if (batch.length < size) return all;
  }
}

/// Shorthand for the repeated `List<dynamic> -> List<Map<String, dynamic>>`
/// cast that every Supabase query needs.
List<Map<String, dynamic>> rows(dynamic data) =>
    (data as List<dynamic>).map((row) => row as Map<String, dynamic>).toList();
