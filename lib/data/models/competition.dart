import 'parsers.dart';

class Competition {
  const Competition({
    required this.id,
    required this.title,
    required this.weekDate,
    required this.maxMark,
    required this.createdBy,
    required this.createdAt,
    this.yearId,
  });

  final String id;
  final String title;
  final DateTime weekDate;
  final int maxMark;
  final String createdBy;
  final DateTime createdAt;
  final String? yearId;

  factory Competition.fromMap(Map<String, dynamic> map) => Competition(
        id: asText(map['id']),
        title: asText(map['title']),
        weekDate: asDate(map['week_date']),
        maxMark: asInt(map['max_mark'], 10),
        createdBy: asText(map['created_by']),
        createdAt: asDate(map['created_at']),
        yearId: asTextOrNull(map['year_id']),
      );

  Competition copyWith({
    String? title,
    DateTime? weekDate,
    int? maxMark,
    String? yearId,
  }) =>
      Competition(
        id: id,
        title: title ?? this.title,
        weekDate: weekDate ?? this.weekDate,
        maxMark: maxMark ?? this.maxMark,
        createdBy: createdBy,
        createdAt: createdAt,
        yearId: yearId ?? this.yearId,
      );
}

class CompetitionMark {
  const CompetitionMark({
    required this.id,
    required this.competitionId,
    required this.childId,
    required this.mark,
    required this.markedBy,
    required this.markedAt,
  });

  final String id;
  final String competitionId;
  final String childId;
  final int mark;
  final String markedBy;
  final DateTime markedAt;

  factory CompetitionMark.fromMap(Map<String, dynamic> map) => CompetitionMark(
        id: asText(map['id']),
        competitionId: asText(map['competition_id']),
        childId: asText(map['child_id']),
        mark: asInt(map['mark']),
        markedBy: asText(map['marked_by']),
        markedAt: asDate(map['marked_at']),
      );
}

class ChildCompetitionScore {
  const ChildCompetitionScore({
    required this.childId,
    required this.childName,
    required this.classId,
    required this.competitionsCount,
    required this.totalMarks,
    required this.avgMark,
  });

  final String childId;
  final String childName;
  final String classId;
  final int competitionsCount;
  final int totalMarks;
  final double avgMark;

  factory ChildCompetitionScore.fromMap(Map<String, dynamic> map) =>
      ChildCompetitionScore(
        childId: asText(map['child_id']),
        childName: asText(map['child_name']),
        classId: asText(map['class_id']),
        competitionsCount: asInt(map['competitions_count']),
        totalMarks: asInt(map['total_marks']),
        avgMark: asDouble(map['avg_mark']),
      );
}
