import 'child.dart';
import 'parsers.dart';

/// An attendance year, which also owns the scoring configuration.
class AttendanceYear {
  const AttendanceYear({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.sessionWeekday,
    required this.pointsSundaySchool,
    required this.pointsVespers,
    required this.pointsMass,
    required this.pointsConfession,
    required this.maxPointsPerSession,
    required this.isCurrent,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int sessionWeekday;
  final int pointsSundaySchool;
  final int pointsVespers;
  final int pointsMass;
  final int pointsConfession;
  final int maxPointsPerSession;
  final bool isCurrent;

  factory AttendanceYear.fromMap(Map<String, dynamic> map) => AttendanceYear(
        id: asText(map['id']),
        name: asText(map['name']),
        startDate: asDate(map['start_date']),
        endDate: asDate(map['end_date']),
        sessionWeekday: asInt(map['session_weekday'], 6),
        pointsSundaySchool: asInt(map['points_sunday_school'], 5),
        pointsVespers: asInt(map['points_vespers'], 5),
        pointsMass: asInt(map['points_mass'], 5),
        pointsConfession: asInt(map['points_confession'], 5),
        maxPointsPerSession: asInt(map['max_points_per_session'], 20),
        isCurrent: asBool(map['is_current']),
      );

  /// How many session days (every [sessionWeekday], a Saturday by default)
  /// fall in the year, both ends included.
  int get sessionCount {
    var day = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    var n = 0;
    while (!day.isAfter(end)) {
      if (day.weekday == sessionWeekday) n++;
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return n;
  }

  /// Whether [date]'s calendar day falls in this year (both ends included).
  bool contains(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}

class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.yearId,
    required this.classId,
    required this.sessionDate,
    required this.isLocked,
    this.notes,
    this.isBreak = false,
  });

  final String id;
  final String yearId;
  final String classId;
  final DateTime sessionDate;
  final bool isLocked;
  final String? notes;

  /// No lesson that Saturday (إجازة / نشاط ترفيهي): shown, but not taken
  /// and left out of every calculation.
  final bool isBreak;

  factory AttendanceSession.fromMap(Map<String, dynamic> map) =>
      AttendanceSession(
        id: asText(map['id']),
        yearId: asText(map['year_id']),
        classId: asText(map['class_id']),
        sessionDate: asDate(map['session_date']),
        isLocked: asBool(map['is_locked']),
        notes: asTextOrNull(map['notes']),
        // The children's view of the day: a counted نشاط ترفيهي is not off.
        isBreak: asBool(map['children_off'] ?? map['is_break']),
      );
}

/// A saved attendance record: the four activities and the score the database
/// derived from them.
class AttendanceRecord {
  const AttendanceRecord({
    required this.sessionId,
    required this.childId,
    required this.sundaySchool,
    required this.vespers,
    required this.mass,
    required this.confession,
    required this.score,
    required this.maxScore,
    this.id,
    this.updatedAt,
    this.updatedByName,
  });

  final String sessionId;
  final String childId;
  final bool sundaySchool;
  final bool vespers;
  final bool mass;
  final bool confession;
  final int score;
  final int maxScore;
  final String? id;
  final DateTime? updatedAt;
  final String? updatedByName;

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) =>
      AttendanceRecord(
        id: asTextOrNull(map['id'] ?? map['record_id']),
        sessionId: asText(map['session_id']),
        childId: asText(map['child_id']),
        sundaySchool: asBool(map['sunday_school']),
        vespers: asBool(map['vespers']),
        mass: asBool(map['mass']),
        confession: asBool(map['confession']),
        score: asInt(map['score']),
        maxScore: asInt(map['max_score'], 20),
        updatedAt: asDateOrNull(map['updated_at']),
        updatedByName: asTextOrNull(map['updated_by_name']),
      );
}

/// One editable line of the attendance screen: a child plus their marks.
///
/// Built by joining the class roster with the saved records, which is why a
/// newly added child shows up with no extra bookkeeping.
class AttendanceEntry {
  AttendanceEntry({
    required this.child,
    required this.sundaySchool,
    required this.vespers,
    required this.mass,
    required this.confession,
    required this.pointsSundaySchool,
    required this.pointsVespers,
    required this.pointsMass,
    required this.pointsConfession,
    required this.isRecorded,
    this.updatedAt,
    this.updatedByName,
  });

  final Child child;
  bool sundaySchool;
  bool vespers;
  bool mass;
  bool confession;
  final int pointsSundaySchool;
  final int pointsVespers;
  final int pointsMass;
  final int pointsConfession;

  /// True when a row already existed in the database for this child, which is
  /// what distinguishes "marked absent" from "not taken yet".
  bool isRecorded;
  DateTime? updatedAt;
  String? updatedByName;

  int get score =>
      (sundaySchool ? pointsSundaySchool : 0) +
      (vespers ? pointsVespers : 0) +
      (mass ? pointsMass : 0) +
      (confession ? pointsConfession : 0);

  int get maxScore =>
      pointsSundaySchool + pointsVespers + pointsMass + pointsConfession;

  bool get isPresent => sundaySchool || vespers || mass || confession;

  factory AttendanceEntry.from({
    required Child child,
    required AttendanceRecord? record,
    required AttendanceYear year,
  }) =>
      AttendanceEntry(
        child: child,
        sundaySchool: record?.sundaySchool ?? false,
        vespers: record?.vespers ?? false,
        mass: record?.mass ?? false,
        confession: record?.confession ?? false,
        pointsSundaySchool: year.pointsSundaySchool,
        pointsVespers: year.pointsVespers,
        pointsMass: year.pointsMass,
        pointsConfession: year.pointsConfession,
        isRecorded: record != null,
        updatedAt: record?.updatedAt,
        updatedByName: record?.updatedByName,
      );

  AttendanceEntry clone() => AttendanceEntry(
        child: child,
        sundaySchool: sundaySchool,
        vespers: vespers,
        mass: mass,
        confession: confession,
        pointsSundaySchool: pointsSundaySchool,
        pointsVespers: pointsVespers,
        pointsMass: pointsMass,
        pointsConfession: pointsConfession,
        isRecorded: isRecorded,
        updatedAt: updatedAt,
        updatedByName: updatedByName,
      );

  /// Takes marks somebody else saved (arriving live, or found on a catch-up)
  /// without undoing what this person has done on screen since the sheet was
  /// opened. A mark this person has not touched takes the saved value; one they
  /// have touched keeps theirs. Either way [original] (what the server holds)
  /// moves to the saved value, so a later save sends only what really differs.
  ///
  /// Returns true when something on screen changed.
  bool mergeRemote(
    AttendanceEntry original, {
    required bool sundaySchool,
    required bool vespers,
    required bool mass,
    required bool confession,
    DateTime? updatedAt,
    String? updatedByName,
  }) {
    var changed = !isRecorded;
    if (this.sundaySchool == original.sundaySchool) {
      changed |= this.sundaySchool != sundaySchool;
      this.sundaySchool = sundaySchool;
    }
    if (this.vespers == original.vespers) {
      changed |= this.vespers != vespers;
      this.vespers = vespers;
    }
    if (this.mass == original.mass) {
      changed |= this.mass != mass;
      this.mass = mass;
    }
    if (this.confession == original.confession) {
      changed |= this.confession != confession;
      this.confession = confession;
    }
    original
      ..sundaySchool = sundaySchool
      ..vespers = vespers
      ..mass = mass
      ..confession = confession;
    for (final e in [this, original]) {
      e.isRecorded = true;
      e.updatedAt = updatedAt ?? e.updatedAt;
      e.updatedByName = updatedByName ?? e.updatedByName;
    }
    return changed;
  }

  bool sameMarksAs(AttendanceEntry other) =>
      sundaySchool == other.sundaySchool &&
      vespers == other.vespers &&
      mass == other.mass &&
      confession == other.confession;

  /// The marks that differ from [original], by column name, with their new
  /// value. Empty when nothing was touched.
  Map<String, bool> changedFlags(AttendanceEntry original) => <String, bool>{
        if (sundaySchool != original.sundaySchool)
          'sunday_school': sundaySchool,
        if (vespers != original.vespers) 'vespers': vespers,
        if (mass != original.mass) 'mass': mass,
        if (confession != original.confession) 'confession': confession,
      };
}

/// What saving one class's Saturday sends, built so that two servants marking
/// the same class on two phones never undo each other:
///
/// * [updates]: a child whose marks this person changed sends only the marks
///   that changed, so the other marks (maybe set by a co-servant since the
///   sheet was opened) are left as they are. Rows with the same set of
///   changed marks travel together, because one request needs equal columns.
/// * [insertIfMissing]: a child nobody touched and who has no row yet is
///   stored as absent, but only if still missing: a row a co-servant saved
///   in the meantime is never replaced.
class AttendanceSavePlan {
  const AttendanceSavePlan({
    required this.updates,
    required this.insertIfMissing,
  });

  factory AttendanceSavePlan.build({
    required String sessionId,
    required List<AttendanceEntry> entries,
    required List<AttendanceEntry> originals,
  }) {
    final groups = <String, List<Map<String, dynamic>>>{};
    final missing = <Map<String, dynamic>>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final changed = entry.changedFlags(originals[i]);
      if (changed.isNotEmpty) {
        (groups[changed.keys.join(',')] ??= []).add(<String, dynamic>{
          'session_id': sessionId,
          'child_id': entry.child.id,
          ...changed,
        });
      } else if (!entry.isRecorded) {
        missing.add(<String, dynamic>{
          'session_id': sessionId,
          'child_id': entry.child.id,
        });
      }
    }
    return AttendanceSavePlan(
      updates: groups.values.toList(),
      insertIfMissing: missing,
    );
  }

  final List<List<Map<String, dynamic>>> updates;
  final List<Map<String, dynamic>> insertIfMissing;

  bool get isEmpty => updates.isEmpty && insertIfMissing.isEmpty;
}

/// Everything the attendance screen needs for one Saturday.
class AttendanceSheet {
  const AttendanceSheet({
    required this.session,
    required this.year,
    required this.entries,
  });

  final AttendanceSession session;
  final AttendanceYear year;
  final List<AttendanceEntry> entries;

  int get maxScore => entries.length * year.maxPointsPerSession;
  int get presentCount => entries.where((entry) => entry.isPresent).length;
  int get recordedCount => entries.where((entry) => entry.isRecorded).length;
}

/// A row of `v_class_session_summary`, used by the attendance history screen.
class SessionSummary {
  const SessionSummary({
    required this.sessionId,
    required this.classId,
    required this.yearId,
    required this.sessionDate,
    required this.isLocked,
    required this.recordedCount,
    required this.presentCount,
    required this.points,
    required this.activeChildren,
  });

  final String sessionId;
  final String classId;
  final String yearId;
  final DateTime sessionDate;
  final bool isLocked;
  final int recordedCount;
  final int presentCount;
  final int points;
  final int activeChildren;

  bool get hasData => recordedCount > 0;

  factory SessionSummary.fromMap(Map<String, dynamic> map) => SessionSummary(
        sessionId: asText(map['session_id']),
        classId: asText(map['class_id']),
        yearId: asText(map['year_id']),
        sessionDate: asDate(map['session_date']),
        isLocked: asBool(map['is_locked']),
        recordedCount: asInt(map['recorded_count']),
        presentCount: asInt(map['present_count']),
        points: asInt(map['points']),
        activeChildren: asInt(map['active_children']),
      );
}

/// A row of `v_session_scores`: one child on one Saturday.
class ChildSessionScore {
  const ChildSessionScore({
    required this.sessionId,
    required this.sessionDate,
    required this.className,
    required this.childId,
    required this.childName,
    required this.gender,
    required this.sundaySchool,
    required this.vespers,
    required this.mass,
    required this.confession,
    required this.score,
    required this.maxScore,
    this.updatedByName,
    this.updatedAt,
    this.isBreak = false,
  });

  final String sessionId;
  final DateTime sessionDate;
  final String className;
  final String childId;
  final String childName;
  final Gender gender;
  final bool sundaySchool;
  final bool vespers;
  final bool mass;
  final bool confession;
  final int score;
  final int maxScore;
  final String? updatedByName;
  final DateTime? updatedAt;

  /// Saved on a Saturday that turned out to have no lesson: kept, not counted.
  final bool isBreak;

  bool get isPresent => sundaySchool || vespers || mass || confession;

  factory ChildSessionScore.fromMap(Map<String, dynamic> map) =>
      ChildSessionScore(
        sessionId: asText(map['session_id']),
        sessionDate: asDate(map['session_date']),
        className: asText(map['class_name']),
        childId: asText(map['child_id']),
        childName: asText(map['child_name']),
        gender: Gender.fromWire(map['gender']),
        sundaySchool: asBool(map['sunday_school']),
        vespers: asBool(map['vespers']),
        mass: asBool(map['mass']),
        confession: asBool(map['confession']),
        score: asInt(map['score']),
        maxScore: asInt(map['max_score'], 20),
        updatedByName: asTextOrNull(map['updated_by_name']),
        updatedAt: asDateOrNull(map['updated_at']),
        isBreak: asBool(map['is_break']),
      );
}
