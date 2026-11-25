import '../../core/l10n/app_strings.dart';
import 'parsers.dart';

/// Who an announcement goes to.
enum AnnouncementAudience {
  all('all', AppStrings.audienceAll),
  servants('servants', AppStrings.audienceServants),
  general('general', AppStrings.audienceGeneral),
  classes('classes', AppStrings.audienceClasses),
  people('people', AppStrings.audiencePeople);

  const AnnouncementAudience(this.value, this.label);

  final String value;
  final String label;

  static AnnouncementAudience parse(String value) => values.firstWhere(
        (a) => a.value == value,
        orElse: () => AnnouncementAudience.all,
      );
}

/// One sent announcement, as the admin's list shows it.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.classNames,
    required this.createdAt,
    required this.recipients,
    required this.readCount,
    this.senderName,
    this.servantNames = const <String>[],
  });

  final String id;
  final String title;
  final String body;
  final AnnouncementAudience audience;
  final List<String> classNames;

  /// The servants chosen by name (audience `people`).
  final List<String> servantNames;
  final String? senderName;
  final DateTime createdAt;
  final int recipients;
  final int readCount;

  /// "الكل" / "خدام الفصول" / "فصل 3 بنين، فصل 4 بنات" / "مينا، مريم و3 غيرهم".
  String get audienceLabel => switch (audience) {
        AnnouncementAudience.classes when classNames.isNotEmpty =>
          classNames.join('، '),
        AnnouncementAudience.people when servantNames.isNotEmpty =>
          namesSummary(servantNames),
        _ => audience.label,
      };

  /// Up to three names, then how many more: "أ، ب، ج و2 غيرهم".
  static String namesSummary(List<String> names) => names.length <= 3
      ? names.join('، ')
      : '${names.take(3).join('، ')} ${AppStrings.andOthers(names.length - 3)}';

  factory Announcement.fromMap(Map<String, dynamic> map) => Announcement(
        id: asText(map['id']),
        title: asText(map['title']),
        body: asText(map['body']),
        audience: AnnouncementAudience.parse(asText(map['audience'])),
        classNames: map['class_names'] is List
            ? [for (final n in map['class_names'] as List) '$n']
            : const <String>[],
        servantNames: map['servant_names'] is List
            ? [for (final n in map['servant_names'] as List) '$n']
            : const <String>[],
        senderName: asTextOrNull(map['sender_name']),
        createdAt: asDate(map['created_at']).toLocal(),
        recipients: asInt(map['recipients']),
        readCount: asInt(map['read_count']),
      );
}

/// One recipient of an announcement and when they read it.
class AnnouncementRead {
  const AnnouncementRead({
    required this.userId,
    required this.fullName,
    this.mobile,
    this.readAt,
  });

  final String userId;
  final String fullName;
  final String? mobile;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory AnnouncementRead.fromMap(Map<String, dynamic> map) =>
      AnnouncementRead(
        userId: asText(map['user_id']),
        fullName: asText(map['full_name']),
        mobile: asTextOrNull(map['mobile']),
        readAt: asDateOrNull(map['read_at'])?.toLocal(),
      );
}
