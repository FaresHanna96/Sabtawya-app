import '../../data/models/child.dart';

/// Arabic names of the child columns an edit can touch. Columns that do not
/// matter to a servant (ids, timestamps) have no entry and are not listed.
/// Visits are left out on purpose: they have their own history card.
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
};

const Set<String> _visitFields = <String>{
  'last_phone_visit_date',
  'last_phone_visit_notes',
  'last_home_visit_date',
  'last_home_visit_notes',
};

const Set<String> _phoneFields = <String>{
  'mobile',
  'mother_mobile',
  'father_mobile',
};

const List<String> _arabicMonths = <String>[
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

bool _blank(Object? v) => v == null || '$v'.trim().isEmpty;

/// One value the way a servant reads it: "أنثى", "نعم", "4 مارس 2015", a
/// phone number kept left to right, long text cut short.
String _show(String field, Object? v) {
  if (v is bool) {
    return field == 'is_active' ? (v ? 'نشط' : 'غير نشط') : (v ? 'نعم' : 'لا');
  }
  var s = '$v'.trim();
  if (field == 'gender') return s == 'girl' ? 'بنت' : 'ولد';
  if (field == 'birth_date') {
    final d = DateTime.tryParse(s);
    if (d != null) return '${d.day} ${_arabicMonths[d.month - 1]} ${d.year}';
  }
  if (s.length > 40) s = '${s.substring(0, 40)}…';
  // A number inside Arabic text would be reordered, so keep it left to right.
  return _phoneFields.contains(field) ? '\u2066$s\u2069' : s;
}

/// One edited field: its name and a sentence saying what happened to it.
class FieldChangeText {
  const FieldChangeText(this.label, this.text);

  final String label;
  final String text;
}

/// Several entries of the same kind, by the same person, on the same day:
/// shown as one line (a form saved three times is one change to a servant).
class ChildChangeGroup {
  ChildChangeGroup({
    required this.latest,
    required this.entity,
    required this.action,
    required this.actorName,
    required this.fields,
    Map<String, ({Object? before, Object? after})>? values,
  }) : values = values ?? <String, ({Object? before, Object? after})>{};

  final DateTime latest;
  final String entity;
  final String action;
  final String? actorName;
  final Set<String> fields;

  /// Per field: the oldest "before" and the newest "after" of the day.
  final Map<String, ({Object? before, Object? after})> values;

  bool get isAttendance => entity == 'attendance_records';

  bool get isAdded => !isAttendance && action == 'insert';

  /// Arabic names of what an edit touched, each once, in the order they were
  /// changed. Empty for attendance, for adding the child, and for old edits.
  List<String> get labels {
    if (isAttendance || isAdded) return const <String>[];
    final labels = <String>[];
    for (final f in {...fields, ...values.keys}) {
      final l = _fieldLabels[f];
      if (l != null && !labels.contains(l)) labels.add(l);
    }
    return labels;
  }

  /// What happened to each field: "من «قديم» إلى «جديد»", "أضاف «جديد»"…
  /// Empty for old entries that never recorded the values.
  List<FieldChangeText> get descriptions {
    if (isAttendance || isAdded) return const <FieldChangeText>[];
    final out = <FieldChangeText>[];
    for (final e in values.entries) {
      final label = _fieldLabels[e.key];
      if (label == null || e.key == 'longitude') continue;
      final before = e.value.before, after = e.value.after;
      if (e.key == 'latitude') {
        out.add(FieldChangeText(
            label,
            _blank(before)
                ? 'تم تحديد الموقع'
                : _blank(after)
                    ? 'تم حذف الموقع'
                    : 'تم تغيير الموقع'));
      } else if (e.key == 'photo_path') {
        out.add(FieldChangeText(
            label,
            _blank(before)
                ? 'تمت إضافة صورة'
                : _blank(after)
                    ? 'تم حذف الصورة'
                    : 'تم تغيير الصورة'));
      } else if (_blank(before) && _blank(after)) {
        continue;
      } else if (_blank(before)) {
        out.add(FieldChangeText(label, 'أضاف «${_show(e.key, after)}»'));
      } else if (_blank(after)) {
        out.add(FieldChangeText(label, 'حذف «${_show(e.key, before)}»'));
      } else {
        out.add(FieldChangeText(label,
            'من «${_show(e.key, before)}» إلى «${_show(e.key, after)}»'));
      }
    }
    return out;
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
/// Edits that only touched visit fields are dropped: visits have their own
/// history.
List<ChildChangeGroup> groupChanges(List<ChildChange> changes) {
  final groups = <ChildChangeGroup>[];
  for (final c in changes) {
    final isEdit = c.entity == 'children' && c.action == 'update';
    if (isEdit && c.changed.isNotEmpty && c.changed.every(_visitFields.contains)) {
      continue;
    }
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
      last.fields.addAll(c.changed.where((f) => !_visitFields.contains(f)));
      // Older entry of the same day: its "before" is the day's starting value.
      for (final e in c.values.entries) {
        final had = last.values[e.key];
        last.values[e.key] =
            (before: e.value.before, after: had == null ? e.value.after : had.after);
      }
    } else {
      groups.add(ChildChangeGroup(
        latest: c.createdAt,
        entity: c.entity,
        action: c.action,
        actorName: c.actorName,
        fields: <String>{...c.changed.where((f) => !_visitFields.contains(f))},
        values: {...c.values},
      ));
    }
  }
  return groups;
}
