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

  static final _dayFirst = RegExp(r'(?<!\d)(\d{1,2})-(\d{1,2})-(\d{4})(?!\d)');
  static final _yearFirst = RegExp(r'(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)');

  /// The day the text is about ("... ليوم 31-10-2026"), so tapping can open
  /// that day. The database writes it into the body, day first or year
  /// first depending on when the entry was made. Null when there is none.
  DateTime? get mentionedDate {
    int n(RegExpMatch m, int g) => int.parse(m.group(g)!);
    DateTime? valid(int y, int mo, int d) {
      final date = DateTime(y, mo, d);
      return date.year == y && date.month == mo && date.day == d ? date : null;
    }

    final a = _yearFirst.firstMatch(body);
    if (a != null) return valid(n(a, 1), n(a, 2), n(a, 3));
    final b = _dayFirst.firstMatch(body);
    if (b != null) return valid(n(b, 3), n(b, 2), n(b, 1));
    return null;
  }

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
