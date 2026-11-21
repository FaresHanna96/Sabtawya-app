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
    this.sessionsAttended = 0,
    this.sessionsTotal = 0,
  });

  final String classId;
  final String className;
  final String yearId;
  final int children;
  final int points;
  final int maxPoints;

  /// Attendance: the class's Saturdays came over Saturdays held so far
  /// (summed over its children).
  final double percentage;
  final int sessionsAttended;
  final int sessionsTotal;

  factory ClassYearScore.fromMap(Map<String, dynamic> map) => ClassYearScore(
        classId: asText(map['class_id']),
        className: asText(map['class_name']),
        yearId: asText(map['year_id']),
        children: asInt(map['children']),
        points: asInt(map['points']),
        maxPoints: asInt(map['max_points']),
        percentage: asDouble(map['percentage']),
        sessionsAttended: asInt(map['sessions_attended']),
        sessionsTotal: asInt(map['sessions_total']),
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
    this.entityId,
    this.details = const <String, dynamic>{},
  });

  final int id;
  final String action;
  final String entity;
  final DateTime createdAt;
  final String? actorName;

  /// The id of the row it is about (a child's id for a `children` entry).
  final String? entityId;
  final Map<String, dynamic> details;

  factory ActivityLogEntry.fromMap(Map<String, dynamic> map) =>
      ActivityLogEntry(
        id: asInt(map['id']),
        action: asText(map['action']),
        entity: asText(map['entity']),
        createdAt: asDate(map['created_at']),
        actorName: asTextOrNull(map['actor_name']),
        entityId: asTextOrNull(map['entity_id']),
        details: (map['details'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      );

  /// Arabic phrasing for the activity feeds: who did what, to whom.
  String get description {
    final who = actorName ?? 'مستخدم';
    final verb = switch (action) {
      'insert' => 'أضاف',
      'update' => 'عدّل',
      'delete' => 'حذف',
      _ => 'غيّر',
    };
    String named(String? name) =>
        (name == null || name.trim().isEmpty) ? '' : ' ${name.trim()}';
    final what = switch (entity) {
      'children' => 'بيانات المخدوم${named(details['name'] as String?)}',
      // Entries from before the child was recorded say only "attendance".
      'attendance_records' => details['child_name'] == null
          ? 'سجل حضور'
          : 'حضور${named(details['child_name'] as String?)}',
      'class_servants' => details['servant_name'] == null
          ? 'تعيين خادم'
          : 'تعيين الخادم${named(details['servant_name'] as String?)}',
      _ => entity,
    };
    return '$who $verb $what';
  }

  /// A second line for the full log: the marks of an attendance entry.
  String? get extra {
    if (entity != 'attendance_records') return null;
    final marks = <String>[
      if (details['sunday_school'] == true) 'مدارس الأحد',
      if (details['vespers'] == true) 'عشية',
      if (details['mass'] == true) 'قداس',
      if (details['confession'] == true) 'اعتراف',
    ];
    if (!details.containsKey('sunday_school')) {
      return details['score'] == null ? null : 'الدرجة ${details['score']}';
    }
    final score = details['score'];
    final text = marks.isEmpty ? 'غائب' : marks.join('، ');
    return score == null ? text : '$text • الدرجة $score';
  }

  /// The child this entry is about, when it names one.
  String? get childId {
    final fromDetails = details['child_id'];
    if (fromDetails != null) return '$fromDetails';
    return entity == 'children' ? entityId : null;
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

/// A row of `v_child_attendance_trend`: how often a child came in the last four
/// Saturdays against the four before (percent of those Saturdays).
class ChildTrend {
  const ChildTrend({
    required this.childId,
    required this.childName,
    required this.classId,
    required this.className,
    required this.recentRate,
    required this.previousRate,
    required this.isDeclining,
  });

  final String childId;
  final String childName;
  final String classId;
  final String className;
  final int recentRate;
  final int previousRate;
  final bool isDeclining;

  /// Percentage points lost (negative when the child improved).
  int get drop => previousRate - recentRate;

  factory ChildTrend.fromMap(Map<String, dynamic> map) => ChildTrend(
        childId: asText(map['child_id']),
        childName: asText(map['child_name']),
        classId: asText(map['class_id']),
        className: asText(map['class_name']),
        recentRate: asDouble(map['recent_rate']).round(),
        previousRate: asDouble(map['previous_rate']).round(),
        isDeclining: map['is_declining'] == true,
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

/// One class on one Saturday: who came out of its active children, and
/// whether it took attendance at all.
class ClassWeek {
  const ClassWeek({
    required this.classId,
    required this.present,
    required this.children,
    required this.recorded,
  });

  final String classId;
  final int present;
  final int children;
  final bool recorded;

  double get percentage => children > 0 ? present / children * 100 : 0;
}

/// Attendance on one Saturday across the classes shown: who came, out of the
/// active children, for the dashboard's weekly chart.
///
/// Every Saturday up to today is kept, also one nobody recorded, so a gap
/// shows instead of vanishing; [isBreak] marks a week with no lesson
/// (lesson_breaks), [isToday] a Saturday still being recorded.
class WeeklyAttendance {
  const WeeklyAttendance({
    required this.date,
    required this.present,
    required this.children,
    this.missingClassIds = const [],
    this.perClass = const [],
    this.isBreak = false,
    this.isToday = false,
  });

  final DateTime date;

  /// Totals over the classes that recorded; a class that did not is left
  /// out (not counted as absent) and listed in [missingClassIds].
  final int present;
  final int children;

  /// Classes that did not take attendance that Saturday.
  final List<String> missingClassIds;

  /// Each class that Saturday, recorded or not.
  final List<ClassWeek> perClass;

  final bool isBreak;
  final bool isToday;

  double get percentage => children > 0 ? present / children * 100 : 0;

  /// At least one class took attendance.
  bool get recorded =>
      perClass.isEmpty ? children > 0 : perClass.any((c) => c.recorded);

  /// Today, with some classes still to record.
  bool get inProgress => isToday && (!recorded || missingClassIds.isNotEmpty);

  /// The Saturday the card's big numbers are about: the latest one recorded
  /// and finished (today only once every class has recorded).
  static WeeklyAttendance? headline(List<WeeklyAttendance> weeks) {
    for (final w in weeks.reversed) {
      if (w.recorded && !w.inProgress) return w;
    }
    return null;
  }

  /// The recorded Saturday before [w], skipping holidays, gaps and today.
  static WeeklyAttendance? previous(
    List<WeeklyAttendance> weeks,
    WeeklyAttendance w,
  ) {
    WeeklyAttendance? found;
    for (final x in weeks) {
      if (!x.date.isBefore(w.date)) break;
      if (x.recorded && !x.inProgress) found = x;
    }
    return found;
  }

  /// Past Saturdays after [after] that nobody recorded and were no holiday.
  static List<WeeklyAttendance> missedAfter(
    List<WeeklyAttendance> weeks,
    WeeklyAttendance? after,
  ) =>
      [
        for (final w in weeks)
          if ((after == null || w.date.isAfter(after.date)) &&
              !w.recorded &&
              !w.isBreak &&
              !w.isToday)
            w,
      ];

  /// Percentage points from [older] to [newer], as shown (rounded).
  static int pointsChange(WeeklyAttendance newer, WeeklyAttendance older) =>
      newer.percentage.round() - older.percentage.round();
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
