import 'child.dart';
import 'parsers.dart';

/// Admin dashboard counters, from `v_admin_stats`.
class AdminStats {
  const AdminStats({
    required this.classesCount,
    required this.servantsCount,
    required this.adminsCount,
    required this.childrenCount,
    required this.boysCount,
    required this.girlsCount,
    required this.totalPoints,
    this.nextSessionDate,
    this.lastSessionDate,
  });

  final int classesCount;
  final int servantsCount;
  final int adminsCount;
  final int childrenCount;
  final int boysCount;
  final int girlsCount;
  final int totalPoints;
  final DateTime? nextSessionDate;

  /// The Saturday attendance is being taken for: the most recent one, or the
  /// first of the year before it starts.
  final DateTime? lastSessionDate;

  factory AdminStats.fromMap(Map<String, dynamic> map) => AdminStats(
        classesCount: asInt(map['classes_count']),
        servantsCount: asInt(map['servants_count']),
        adminsCount: asInt(map['admins_count']),
        childrenCount: asInt(map['children_count']),
        boysCount: asInt(map['boys_count']),
        girlsCount: asInt(map['girls_count']),
        totalPoints: asInt(map['total_points']),
        nextSessionDate: asDateOrNull(map['next_session_date']),
        lastSessionDate: asDateOrNull(map['last_session_date']),
      );

  static const empty = AdminStats(
    classesCount: 0,
    servantsCount: 0,
    adminsCount: 0,
    childrenCount: 0,
    boysCount: 0,
    girlsCount: 0,
    totalPoints: 0,
  );
}

/// A row of `v_child_year_report`: a child's standing for a whole year.
class ChildYearReport {
  const ChildYearReport({
    required this.childId,
    required this.childName,
    required this.gender,
    required this.classId,
    required this.className,
    required this.yearId,
    required this.sessionsTotal,
    required this.sessionsAttended,
    required this.points,
    required this.maxPoints,
    required this.percentage,
    required this.childIsActive,
    this.birthDate,
    this.childCode,
    this.childMobile,
    this.school,
    this.yearName,
  });

  final String childId;
  final String childName;
  final Gender gender;
  final String classId;
  final String className;
  final String yearId;
  final int sessionsTotal;
  final int sessionsAttended;
  final int points;
  final int maxPoints;
  final double percentage;
  final bool childIsActive;
  final DateTime? birthDate;
  final String? childCode;
  final String? childMobile;
  final String? school;
  final String? yearName;

  factory ChildYearReport.fromMap(Map<String, dynamic> map) => ChildYearReport(
        childId: asText(map['child_id']),
        childName: asText(map['child_name']),
        gender: Gender.fromWire(map['gender']),
        classId: asText(map['class_id']),
        className: asText(map['class_name']),
        yearId: asText(map['year_id']),
        sessionsTotal: asInt(map['sessions_total']),
        sessionsAttended: asInt(map['sessions_attended']),
        points: asInt(map['points']),
        maxPoints: asInt(map['max_points']),
        percentage: asDouble(map['percentage']),
        childIsActive: asBool(map['child_is_active'], true),
        birthDate: asDateOrNull(map['birth_date']),
        childCode: asTextOrNull(map['child_code']),
        childMobile: asTextOrNull(map['child_mobile']),
        school: asTextOrNull(map['school']),
        yearName: asTextOrNull(map['year_name']),
      );
}

/// A row of `v_child_monthly_report`.
class ChildMonthlyReport {
  const ChildMonthlyReport({
    required this.childId,
    required this.childName,
    required this.gender,
    required this.classId,
    required this.className,
    required this.yearId,
    required this.monthStart,
    required this.sessionsTotal,
    required this.sessionsAttended,
    required this.points,
    required this.maxPoints,
    required this.percentage,
    required this.childIsActive,
  });

  final String childId;
  final String childName;
  final Gender gender;
  final String classId;
  final String className;
  final String yearId;
  final DateTime monthStart;
  final int sessionsTotal;
  final int sessionsAttended;
  final int points;
  final int maxPoints;
  final double percentage;
  final bool childIsActive;

  factory ChildMonthlyReport.fromMap(Map<String, dynamic> map) =>
      ChildMonthlyReport(
        childId: asText(map['child_id']),
        childName: asText(map['child_name']),
        gender: Gender.fromWire(map['gender']),
        classId: asText(map['class_id']),
        className: asText(map['class_name']),
        yearId: asText(map['year_id']),
        monthStart: asDate(map['month_start']),
        sessionsTotal: asInt(map['sessions_total']),
        sessionsAttended: asInt(map['sessions_attended']),
        points: asInt(map['points']),
        maxPoints: asInt(map['max_points']),
        percentage: asDouble(map['percentage']),
        childIsActive: asBool(map['child_is_active'], true),
      );
}

/// A row of `v_class_year_scores`.
class ClassYearScore {
  const ClassYearScore({
    required this.classId,
    required this.className,
    required this.yearId,
    required this.children,
    required this.points,
    required this.maxPoints,
    required this.percentage,
  });

  final String classId;
  final String className;
  final String yearId;
  final int children;
  final int points;
  final int maxPoints;
  final double percentage;

  factory ClassYearScore.fromMap(Map<String, dynamic> map) => ClassYearScore(
        classId: asText(map['class_id']),
        className: asText(map['class_name']),
        yearId: asText(map['year_id']),
        children: asInt(map['children']),
        points: asInt(map['points']),
        maxPoints: asInt(map['max_points']),
        percentage: asDouble(map['percentage']),
      );
}

/// A row of `v_child_last_activity`: when the child last did each activity.
///
/// A null date means they have never been marked for that activity, which the
/// profile shows as لم يحضر بعد rather than as an empty cell.
class ChildLastActivity {
  const ChildLastActivity({
    required this.childId,
    this.lastSundaySchool,
    this.lastVespers,
    this.lastMass,
    this.lastConfession,
    this.lastPresent,
  });

  final String childId;
  final DateTime? lastSundaySchool;
  final DateTime? lastVespers;
  final DateTime? lastMass;
  final DateTime? lastConfession;

  /// The last Saturday the child earned any points at all.
  final DateTime? lastPresent;

  bool get hasAny =>
      lastSundaySchool != null ||
      lastVespers != null ||
      lastMass != null ||
      lastConfession != null;

  factory ChildLastActivity.fromMap(Map<String, dynamic> map) =>
      ChildLastActivity(
        childId: asText(map['child_id']),
        lastSundaySchool: asDateOrNull(map['last_sunday_school']),
        lastVespers: asDateOrNull(map['last_vespers']),
        lastMass: asDateOrNull(map['last_mass']),
        lastConfession: asDateOrNull(map['last_confession']),
        lastPresent: asDateOrNull(map['last_present']),
      );
}

/// A row of `v_child_commitment`.
///
/// Rates are measured against the Saturdays that have already happened, so they
/// stay meaningful in the first weeks of the year.
class ChildCommitment {
  const ChildCommitment({
    required this.childId,
    required this.childName,
    required this.gender,
    required this.classId,
    required this.className,
    required this.sessionsHeld,
    required this.sessionsAttended,
    required this.points,
    required this.maxPoints,
    required this.currentStreak,
    required this.pointsPercentage,
    required this.attendancePercentage,
    this.photoPath,
  });

  final String childId;
  final String childName;
  final Gender gender;
  final String classId;
  final String className;
  final int sessionsHeld;
  final int sessionsAttended;
  final int points;
  final int maxPoints;

  /// Saturdays attended in a row, counting back from the most recent one.
  final int currentStreak;
  final double pointsPercentage;
  final double attendancePercentage;
  final String? photoPath;

  bool get attendedEverySaturday =>
      sessionsHeld > 0 && sessionsAttended == sessionsHeld;

  factory ChildCommitment.fromMap(Map<String, dynamic> map) => ChildCommitment(
        childId: asText(map['child_id']),
        childName: asText(map['child_name']),
        gender: Gender.fromWire(map['gender']),
        classId: asText(map['class_id']),
        className: asText(map['class_name']),
        sessionsHeld: asInt(map['sessions_held']),
        sessionsAttended: asInt(map['sessions_attended']),
        points: asInt(map['points']),
        maxPoints: asInt(map['max_points']),
        currentStreak: asInt(map['current_streak']),
        pointsPercentage: asDouble(map['points_percentage']),
        attendancePercentage: asDouble(map['attendance_percentage']),
        photoPath: asTextOrNull(map['photo_path']),
      );

  Child get asChild => Child(
        id: childId,
        classId: classId,
        fullName: childName,
        gender: gender,
        isActive: true,
        photoPath: photoPath,
      );
}

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.action,
    required this.entity,
    required this.createdAt,
    this.actorName,
    this.details = const <String, dynamic>{},
  });

  final int id;
  final String action;
  final String entity;
  final DateTime createdAt;
  final String? actorName;
  final Map<String, dynamic> details;

  factory ActivityLogEntry.fromMap(Map<String, dynamic> map) =>
      ActivityLogEntry(
        id: asInt(map['id']),
        action: asText(map['action']),
        entity: asText(map['entity']),
        createdAt: asDate(map['created_at']),
        actorName: asTextOrNull(map['actor_name']),
        details: (map['details'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      );

  /// Arabic phrasing for the admin dashboard activity feed.
  String get description {
    final who = actorName ?? 'مستخدم';
    final verb = switch (action) {
      'insert' => 'أضاف',
      'update' => 'عدّل',
      'delete' => 'حذف',
      _ => 'غيّر',
    };
    final what = switch (entity) {
      'children' => 'بيانات المخدوم ${details['name'] ?? ''}'.trim(),
      'attendance_records' => 'سجل حضور',
      'class_servants' => 'تعيين خادم',
      _ => entity,
    };
    return '$who $verb $what';
  }
}

/// How many Saturdays in a row a child has been absent / present, counting
/// back from the latest Saturday whose attendance was taken.
class ChildStreak {
  const ChildStreak({
    required this.childId,
    required this.childName,
    required this.classId,
    required this.className,
    required this.absentStreak,
    required this.presentStreak,
    this.lastPresentDate,
  });

  final String childId;
  final String childName;
  final String classId;
  final String className;
  final int absentStreak;
  final int presentStreak;
  final DateTime? lastPresentDate;

  factory ChildStreak.fromMap(Map<String, dynamic> map) => ChildStreak(
        childId: asText(map['child_id']),
        childName: asText(map['child_name']),
        classId: asText(map['class_id']),
        className: asText(map['class_name']),
        absentStreak: asInt(map['absent_streak']),
        presentStreak: asInt(map['present_streak']),
        lastPresentDate: asDateOrNull(map['last_present_date']),
      );
}

/// A row of `v_child_activity_rates`: how many of the Saturdays held so far
/// the child came to each activity.
class ChildActivityRate {
  const ChildActivityRate({
    required this.childId,
    required this.childName,
    required this.classId,
    required this.className,
    required this.held,
    required this.sundaySchool,
    required this.vespers,
    required this.mass,
    required this.confession,
  });

  final String childId;
  final String childName;
  final String classId;
  final String className;
  final int held;
  final int sundaySchool;
  final int vespers;
  final int mass;
  final int confession;

  /// The four counts in the app's order: Sunday school, vespers, mass,
  /// confession.
  List<int> get counts => [sundaySchool, vespers, mass, confession];

  double rate(int count) => held > 0 ? count / held * 100 : 0;

  factory ChildActivityRate.fromMap(Map<String, dynamic> map) =>
      ChildActivityRate(
        childId: asText(map['child_id']),
        childName: asText(map['child_name']),
        classId: asText(map['class_id']),
        className: asText(map['class_name']),
        held: asInt(map['held']),
        sundaySchool: asInt(map['sunday_school']),
        vespers: asInt(map['vespers']),
        mass: asInt(map['mass']),
        confession: asInt(map['confession']),
      );
}

/// Attendance on one Saturday across the classes shown: who came, out of the
/// active children, for the dashboard's weekly chart.
class WeeklyAttendance {
  const WeeklyAttendance({
    required this.date,
    required this.present,
    required this.children,
    this.missingClassIds = const [],
  });

  final DateTime date;
  final int present;
  final int children;

  /// Classes that did not take attendance that Saturday: left out of
  /// [children] (not counted as absent), and named on the card.
  final List<String> missingClassIds;

  double get percentage => children > 0 ? present / children * 100 : 0;
}

/// One child's score at one Saturday, for reports over an exact date range.
class SessionScore {
  const SessionScore({
    required this.childId,
    required this.childName,
    required this.classId,
    required this.className,
    required this.sessionDate,
    required this.score,
  });

  final String childId;
  final String childName;
  final String classId;
  final String className;
  final DateTime sessionDate;
  final int score;

  bool get present => score > 0;

  factory SessionScore.fromMap(Map<String, dynamic> map) {
    final session = (map['attendance_sessions'] as Map).cast<String, dynamic>();
    final child = (map['children'] as Map).cast<String, dynamic>();
    final cls = child['classes'];
    return SessionScore(
      childId: asText(map['child_id']),
      childName: asText(child['full_name']),
      classId: asText(session['class_id']),
      className: cls is Map ? asText(cls['name']) : '',
      sessionDate: asDate(session['session_date']),
      score: asInt(map['score']),
    );
  }
}
