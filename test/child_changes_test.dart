import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/child_changes.dart';
import 'package:sabtawya/data/models/child.dart';

ChildChange c(String at, {String? by, String entity = 'children',
    String action = 'update', List<String> changed = const []}) =>
    ChildChange(
        createdAt: DateTime.parse(at),
        action: action,
        entity: entity,
        actorName: by,
        changed: changed);

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
        'عدّل: الموقع، الافتقاد');
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
}
