import 'parsers.dart';

/// One entry of the bell: a sign-up, a review, a lesson change.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.refId,
  });

  final String id;

  /// 'signup' | 'decision' | 'prep_submitted' | 'prep_reviewed' | 'lesson_changed'
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  /// What it is about: a servant, a child or a class, depending on [kind].
  final String? refId;

  bool get isRead => readAt != null;

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: asText(map['id']),
        kind: asText(map['kind']),
        title: asText(map['title']),
        body: asText(map['body']),
        createdAt: asDate(map['created_at']).toLocal(),
        readAt: asDateOrNull(map['read_at']),
        refId: asTextOrNull(map['ref_id']),
      );
}
