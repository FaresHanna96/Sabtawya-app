import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/child_changes.dart';
import 'package:sabtawya/data/models/child.dart';

ChildChange c(String at, {String? by, String entity = 'children',
    String action = 'update', List<String> changed = const [],
    Map<String, ({Object? before, Object? after})> values = const {}}) =>
    ChildChange(
        createdAt: DateTime.parse(at),
        action: action,
        entity: entity,
        actorName: by,
        changed: changed,
        values: values);

void main() {
  test('same person, same day, same kind is one line with every field', () {
    final g = groupChanges([
      c('2026-11-13T12:00:00', by: 'فارس', changed: ['mother_mobile']),
      c('2026-11-13T09:00:00', by: 'فارس', changed: ['address', 'mother_mobile']),
    ]);
    expect(g, hasLength(1));
    expect(g.single.title, 'عدّل: رقم الأم، العنوان');
  });

  test('another person, another day or another kind stays separate', () {
    final g = groupChanges([
      c('2026-11-13T12:00:00', by: 'فارس'),
      c('2026-11-13T11:00:00', by: 'مينا'),
      c('2026-11-12T11:00:00', by: 'مينا'),
      c('2026-11-12T10:00:00', by: 'مينا', entity: 'attendance_records'),
    ]);
    expect(g, hasLength(4));
  });

  test('titles: old entries, attendance, many fields, location and visits', () {
    expect(groupChanges([c('2026-11-13T12:00:00')]).single.title,
        'عدّل بيانات المخدوم');
    expect(
        groupChanges([c('2026-11-13T12:00:00', entity: 'attendance_records')])
            .single
            .title,
        'سجّل الحضور');
    expect(
        groupChanges([
          c('2026-11-13T12:00:00',
              changed: ['latitude', 'longitude', 'last_phone_visit_date'])
        ]).single.title,
        'عدّل: الموقع');
    expect(
        groupChanges([
          c('2026-11-13T12:00:00',
              changed: ['school', 'address', 'notes', 'mobile'])
        ]).single.title,
        endsWith('وغيرها'));
  });

  test('no name means the system, not an empty "by"', () {
    expect(groupChanges([c('2026-11-13T12:00:00')]).single.by, 'النظام');
    expect(groupChanges([c('2026-11-13T12:00:00', by: 'فارس')]).single.by,
        'فارس');
  });

  test('visit-only edits are not listed, visit fields never shown', () {
    final g = groupChanges([
      c('2026-11-13T12:00:00',
          by: 'فارس', changed: ['last_phone_visit_date', 'last_phone_visit_notes']),
      c('2026-11-12T12:00:00',
          by: 'فارس', changed: ['address', 'last_home_visit_date']),
    ]);
    expect(g, hasLength(1));
    expect(g.single.labels, ['العنوان']);
  });

  test('describes each change: from-to, added, removed, location, photo', () {
    final g = groupChanges([
      c('2026-11-13T12:00:00', by: 'فارس', changed: [
        'address', 'mother_mobile', 'father_name', 'gender', 'latitude',
        'longitude', 'photo_path', 'is_active'
      ], values: {
        'address': (before: 'شارع أ', after: 'شارع ب'),
        'mother_mobile': (before: null, after: '01012345678'),
        'father_name': (before: 'مينا', after: ''),
        'gender': (before: 'boy', after: 'girl'),
        'latitude': (before: null, after: 30.1),
        'longitude': (before: null, after: 31.2),
        'photo_path': (before: 'a.jpg', after: 'b.jpg'),
        'is_active': (before: true, after: false),
      }),
    ]).single.descriptions;
    final byLabel = {for (final d in g) d.label: d.text};
    expect(byLabel['العنوان'], 'من «شارع أ» إلى «شارع ب»');
    expect(byLabel['رقم الأم'], contains('01012345678'));
    expect(byLabel['رقم الأم'], startsWith('أضاف'));
    expect(byLabel['اسم الأب'], 'حذف «مينا»');
    expect(byLabel['النوع'], 'من «ولد» إلى «بنت»');
    expect(byLabel['الموقع'], 'تم تحديد الموقع');
    expect(byLabel['الصورة'], 'تم تغيير الصورة');
    expect(byLabel['الحالة'], 'من «نشط» إلى «غير نشط»');
    expect(g.where((d) => d.label == 'الموقع'), hasLength(1));
  });

  test('same-day edits keep the first before and the last after', () {
    final g = groupChanges([
      c('2026-11-13T12:00:00', by: 'فارس', changed: ['address'],
          values: {'address': (before: 'ب', after: 'ج')}),
      c('2026-11-13T09:00:00', by: 'فارس', changed: ['address'],
          values: {'address': (before: 'أ', after: 'ب')}),
    ]).single.descriptions;
    expect(g.single.text, 'من «أ» إلى «ج»');
  });

  test('ChildChange.fromMap reads the recorded values', () {
    final ch = ChildChange.fromMap({
      'created_at': '2026-11-13T12:00:00Z',
      'action': 'update',
      'entity': 'children',
      'changed': ['address'],
      'changes': {
        'address': {'old': 'أ', 'new': 'ب'}
      },
    });
    expect(ch.values['address']!.before, 'أ');
    expect(ch.values['address']!.after, 'ب');
  });
}
