import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/reports.dart';

ActivityLogEntry _entry(
  String entity,
  Map<String, dynamic> details, {
  String action = 'update',
  String? entityId,
  String? actor = 'أبانوب',
}) =>
    ActivityLogEntry.fromMap({
      'id': 1,
      'action': action,
      'entity': entity,
      'entity_id': entityId,
      'actor_name': actor,
      'created_at': '2026-11-16T10:00:00Z',
      'details': details,
    });

void main() {
  group('attendance entries', () {
    test('name the child and show the marks', () {
      final e = _entry('attendance_records', {
        'child_id': 'k1',
        'child_name': 'مينا عادل',
        'score': 10,
        'sunday_school': true,
        'vespers': false,
        'mass': true,
        'confession': false,
      });
      expect(e.description, 'أبانوب عدّل حضور مينا عادل');
      expect(e.extra, 'مدارس الأحد، قداس • الدرجة 10');
      expect(e.childId, 'k1');
    });

    test('an absent child is said to be absent', () {
      final e = _entry(
          'attendance_records',
          {
            'child_id': 'k1',
            'child_name': 'مينا',
            'score': 0,
            'sunday_school': false,
            'vespers': false,
            'mass': false,
            'confession': false,
          },
          action: 'insert');
      expect(e.description, 'أبانوب أضاف حضور مينا');
      expect(e.extra, 'غائب • الدرجة 0');
    });

    test('an entry from before children were named still reads', () {
      final e = _entry('attendance_records', {'session_id': 's', 'score': 15});
      expect(e.description, 'أبانوب عدّل سجل حضور');
      expect(e.extra, 'الدرجة 15');
      expect(e.childId, isNull);
    });
  });

  group('other entries', () {
    test('a child entry is about that child, by its row id', () {
      final e = _entry('children', {'name': 'بولا'}, entityId: 'k9');
      expect(e.description, 'أبانوب عدّل بيانات المخدوم بولا');
      expect(e.childId, 'k9');
      expect(e.extra, isNull);
    });

    test('an assignment names the servant when it was recorded', () {
      final named =
          _entry('class_servants', {'servant_name': 'مريم'}, action: 'insert');
      expect(named.description, 'أبانوب أضاف تعيين الخادم مريم');
      final old = _entry('class_servants', {}, action: 'delete');
      expect(old.description, 'أبانوب حذف تعيين خادم');
    });

    test('no actor and an unknown kind still read', () {
      final e = _entry('profiles', {}, actor: null, action: 'insert');
      expect(e.description, 'مستخدم أضاف profiles');
    });
  });
}
