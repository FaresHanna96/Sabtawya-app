import 'parsers.dart';

/// Lesson prep submission by a servant for a specific attendance session.
class LessonPrep {
  const LessonPrep({
    required this.id,
    required this.servantId,
    required this.servantName,
    required this.sessionId,
    required this.sessionDate,
    required this.status,
    required this.photos,
    this.adminComment,
    this.reviewedBy,
    this.reviewedAt,
    this.createdAt,
  });

  final String id;
  final String servantId;
  final String servantName;
  final String sessionId;
  final DateTime sessionDate;

  /// 'pending' | 'accepted' | 'commented'
  final String status;
  final List<LessonPrepPhoto> photos;
  final String? adminComment;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCommented => status == 'commented';

  factory LessonPrep.fromMap(Map<String, dynamic> map) {
    final rawPhotos = map['servant_lesson_prep_photos'];
    final photos = rawPhotos is List
        ? rawPhotos
            .map((p) => LessonPrepPhoto.fromMap(p as Map<String, dynamic>))
            .toList()
        : <LessonPrepPhoto>[];

    final session = map['attendance_sessions'] as Map<String, dynamic>?;
    final profile = map['profiles'] as Map<String, dynamic>?;

    return LessonPrep(
      id: asText(map['id']),
      servantId: asText(map['servant_id']),
      servantName: asText(profile?['full_name']),
      sessionId: asText(map['session_id']),
      sessionDate: asDate(session?['session_date']),
      status: asText(map['status'], 'pending'),
      photos: photos,
      adminComment: asTextOrNull(map['admin_comment']),
      reviewedBy: asTextOrNull(map['reviewed_by']),
      reviewedAt: asDateOrNull(map['reviewed_at']),
      createdAt: asDateOrNull(map['created_at']),
    );
  }
}

class LessonPrepPhoto {
  const LessonPrepPhoto({
    required this.id,
    required this.prepId,
    required this.storagePath,
    this.createdAt,
  });

  final String id;
  final String prepId;
  final String storagePath;
  final DateTime? createdAt;

  factory LessonPrepPhoto.fromMap(Map<String, dynamic> map) => LessonPrepPhoto(
        id: asText(map['id']),
        prepId: asText(map['prep_id']),
        storagePath: asText(map['storage_path']),
        createdAt: asDateOrNull(map['created_at']),
      );
}

/// Admin-recorded attendance for a servant (Sunday school or servant meeting).
class ServantAttendance {
  const ServantAttendance({
    required this.id,
    required this.servantId,
    required this.activityType,
    required this.date,
    required this.recordedBy,
    this.createdAt,
  });

  final String id;
  final String servantId;

  /// 'sunday_school' | 'servant_meeting'
  final String activityType;
  final DateTime date;
  final String recordedBy;
  final DateTime? createdAt;

  bool get isSundaySchool => activityType == 'sunday_school';
  bool get isServantMeeting => activityType == 'servant_meeting';

  factory ServantAttendance.fromMap(Map<String, dynamic> map) =>
      ServantAttendance(
        id: asText(map['id']),
        servantId: asText(map['servant_id']),
        activityType: asText(map['activity_type']),
        date: asDate(map['date']),
        recordedBy: asText(map['recorded_by']),
        createdAt: asDateOrNull(map['created_at']),
      );
}

/// Per-servant stats for a single calendar month (for Excel monthly export).
class ServantMonthlyReport {
  const ServantMonthlyReport({
    required this.servantId,
    required this.servantName,
    required this.sundaySchool,
    required this.servantMeeting,
    required this.prepsCount,
    this.mass = 0,
    this.confession = 0,
  });

  final String servantId;
  final String servantName;
  final int sundaySchool;
  final int servantMeeting;
  final int prepsCount;
  final int mass;
  final int confession;
}

/// Summary data used on the admin servant list.
class ServantActivitySummary {
  const ServantActivitySummary({
    required this.servantId,
    required this.servantName,
    required this.totalPreps,
    required this.pendingPreps,
    required this.sundaySchoolCount,
    required this.servantMeetingCount,
    required this.massCount,
    required this.confessionCount,
  });

  final String servantId;
  final String servantName;
  final int totalPreps;
  final int pendingPreps;
  final int sundaySchoolCount;
  final int servantMeetingCount;
  final int massCount;
  final int confessionCount;
}
