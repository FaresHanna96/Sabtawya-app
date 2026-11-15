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
}

class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.yearId,
    required this.classId,
    required this.sessionDate,
    required this.isLocked,
    this.notes,
  });

  final String id;
  final String yearId;
  final String classId;
  final DateTime sessionDate;
  final bool isLocked;
  final String? notes;

  factory AttendanceSession.fromMap(Map<String, dynamic> map) =>
      AttendanceSession(
        id: asText(map['id']),
        yearId: asText(map['year_id']),
        classId: asText(map['class_id']),
        sessionDate: asDate(map['session_date']),
        isLocked: asBool(map['is_locked']),
        notes: asTextOrNull(map['notes']),
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
  final bool isRecorded;
  final DateTime? updatedAt;
  final String? updatedByName;

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

  bool sameMarksAs(AttendanceEntry other) =>
      sundaySchool == other.sundaySchool &&
      vespers == other.vespers &&
      mass == other.mass &&
      confession == other.confession;

  /// Only the four flags are sent. The score is recomputed by the database so
  /// a client can never write an arbitrary grade.
  Map<String, dynamic> toUpsertMap(String sessionId) => <String, dynamic>{
        'session_id': sessionId,
        'child_id': child.id,
        'sunday_school': sundaySchool,
        'vespers': vespers,
        'mass': mass,
        'confession': confession,
      };

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

  int get totalScore => entries.fold(0, (sum, entry) => sum + entry.score);
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
      );
}
