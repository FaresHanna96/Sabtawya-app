import '../../data/models/child.dart';

/// Arabic names of the child columns an edit can touch. Columns that do not
/// matter to a servant (ids, timestamps) have no entry and are not listed.
const Map<String, String> _fieldLabels = <String, String>{
  'full_name': 'الاسم',
  'gender': 'النوع',
  'birth_date': 'تاريخ الميلاد',
  'mobile': 'رقم المخدوم',
  'mother_name': 'اسم الأم',
  'mother_mobile': 'رقم الأم',
  'father_name': 'اسم الأب',
  'father_mobile': 'رقم الأب',
  'confession_father': 'أب الاعتراف',
  'school': 'المدرسة',
  'address': 'العنوان',
  'notes': 'ملاحظات',
  'is_active': 'الحالة',
  'class_id': 'الفصل',
  'photo_path': 'الصورة',
  'is_deacon': 'الشمامسة',
  'latitude': 'الموقع',
  'longitude': 'الموقع',
  'last_phone_visit_date': 'الافتقاد',
  'last_phone_visit_notes': 'الافتقاد',
  'last_home_visit_date': 'الافتقاد',
  'last_home_visit_notes': 'الافتقاد',
};

/// Several entries of the same kind, by the same person, on the same day:
/// shown as one line (a form saved three times is one change to a servant).
class ChildChangeGroup {
  ChildChangeGroup({
    required this.latest,
    required this.entity,
    required this.action,
    required this.actorName,
    required this.fields,
  });

  final DateTime latest;
  final String entity;
  final String action;
  final String? actorName;
  final Set<String> fields;

  bool get isAttendance => entity == 'attendance_records';

  bool get isAdded => !isAttendance && action == 'insert';

  /// Arabic names of what an edit touched, each once, in the order they were
  /// changed. Empty for attendance, for adding the child, and for old edits.
  List<String> get labels {
    if (isAttendance || isAdded) return const <String>[];
    final labels = <String>[];
    for (final f in fields) {
      final l = _fieldLabels[f];
      if (l != null && !labels.contains(l)) labels.add(l);
    }
    return labels;
  }

  /// "عدّل: رقم الأم، العنوان", "سجّل الحضور" and so on.
  String get title {
    if (isAttendance) return 'سجّل الحضور';
    if (isAdded) return 'أضاف المخدوم';
    final labels = this.labels;
    if (labels.isEmpty) return 'عدّل بيانات المخدوم';
    final shown = labels.take(3).join('، ');
    return labels.length > 3 ? 'عدّل: $shown وغيرها' : 'عدّل: $shown';
  }

  /// False for what was done from the database itself, with no person behind.
  bool get hasActor => actorName != null && actorName!.isNotEmpty;

  /// A person's name, or "النظام" for what was done from the database itself.
  String get by => hasActor ? actorName! : 'النظام';
}

/// [changes] must be newest first (the database returns them that way).
List<ChildChangeGroup> groupChanges(List<ChildChange> changes) {
  final groups = <ChildChangeGroup>[];
  for (final c in changes) {
    final last = groups.isEmpty ? null : groups.last;
    final sameDay = last != null &&
        last.latest.toLocal().year == c.createdAt.toLocal().year &&
        last.latest.toLocal().month == c.createdAt.toLocal().month &&
        last.latest.toLocal().day == c.createdAt.toLocal().day;
    if (last != null &&
        sameDay &&
        last.entity == c.entity &&
        last.action == c.action &&
        last.actorName == c.actorName) {
      last.fields.addAll(c.changed);
    } else {
      groups.add(ChildChangeGroup(
        latest: c.createdAt,
        entity: c.entity,
        action: c.action,
        actorName: c.actorName,
        fields: <String>{...c.changed},
      ));
    }
  }
  return groups;
}
