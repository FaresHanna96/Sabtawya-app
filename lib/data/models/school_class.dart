import 'parsers.dart';

class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    this.description,
    this.patronName,
    this.patronPhotoPath,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;
  final String? description;

  /// The saint the class is named after, and the object path of their picture
  /// in the `class-patrons` bucket.
  final String? patronName;
  final String? patronPhotoPath;

  bool get hasPatronPhoto =>
      patronPhotoPath != null && patronPhotoPath!.isNotEmpty;

  factory SchoolClass.fromMap(Map<String, dynamic> map) => SchoolClass(
        id: asText(map['id']),
        name: asText(map['name']),
        sortOrder: asInt(map['sort_order']),
        isActive: asBool(map['is_active'], true),
        description: asTextOrNull(map['description']),
        patronName: asTextOrNull(map['patron_name']),
        patronPhotoPath: asTextOrNull(map['patron_photo_path']),
      );
}

/// A row of `v_class_overview`, carrying the counters both dashboards need.
class ClassOverview {
  const ClassOverview({
    required this.classId,
    required this.className,
    required this.sortOrder,
    required this.isActive,
    required this.activeChildren,
    required this.boysCount,
    required this.girlsCount,
    required this.servantsCount,
    this.description,
    this.nextSessionDate,
    this.lastSessionDate,
    this.patronName,
    this.patronPhotoPath,
  });

  final String classId;
  final String className;
  final int sortOrder;
  final bool isActive;
  final int activeChildren;
  final int boysCount;
  final int girlsCount;
  final int servantsCount;
  final String? description;
  final DateTime? nextSessionDate;

  /// The Saturday being recorded: the most recent one, or the first of the year
  /// before it starts.
  final DateTime? lastSessionDate;
  final String? patronName;
  final String? patronPhotoPath;

  SchoolClass get asClass => SchoolClass(
        id: classId,
        name: className,
        sortOrder: sortOrder,
        isActive: isActive,
        description: description,
        patronName: patronName,
        patronPhotoPath: patronPhotoPath,
      );

  factory ClassOverview.fromMap(Map<String, dynamic> map) => ClassOverview(
        classId: asText(map['class_id']),
        className: asText(map['class_name']),
        sortOrder: asInt(map['sort_order']),
        isActive: asBool(map['is_active'], true),
        activeChildren: asInt(map['active_children']),
        boysCount: asInt(map['boys_count']),
        girlsCount: asInt(map['girls_count']),
        servantsCount: asInt(map['servants_count']),
        description: asTextOrNull(map['description']),
        nextSessionDate: asDateOrNull(map['next_session_date']),
        lastSessionDate: asDateOrNull(map['last_session_date']),
        patronName: asTextOrNull(map['patron_name']),
        patronPhotoPath: asTextOrNull(map['patron_photo_path']),
      );
}
