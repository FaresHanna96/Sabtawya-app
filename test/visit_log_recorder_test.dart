import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/child.dart';

void main() {
  changeTests();
  Map<String, dynamic> row(Object? recorder) => {
        'id': '1',
        'child_id': 'c',
        'visit_type': 'phone',
        'visit_date': '2026-11-11',
        'created_at': '2026-11-11T10:00:00Z',
        'recorded_by': 'u1',
        'recorder': recorder,
      };

  test('the servant who wrote the visit is read from the joined profile', () {
    final log = ChildVisitLog.fromMap(row({'full_name': 'مينا جورج'}));
    expect(log.recorderName, 'مينا جورج');
  });

  test('no name when the profile is not visible or the account is gone', () {
    expect(ChildVisitLog.fromMap(row(null)).recorderName, isNull);
    expect(ChildVisitLog.fromMap(row(<String, dynamic>{})).recorderName,
        isNull);
  });
}

void changeTests() {
  test('a change line reads who did what', () {
    final c = ChildChange.fromMap({
      'created_at': '2026-11-14T10:00:00Z',
      'action': 'update',
      'entity': 'attendance_records',
      'actor_name': 'مينا جورج',
    });
    expect(c.isAttendance, isTrue);
    expect(c.actorName, 'مينا جورج');
    expect(
        ChildChange.fromMap({
          'created_at': '2026-11-14T10:00:00Z',
          'action': 'insert',
          'entity': 'children',
        }).actorName,
        isNull);
  });
}
