import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/visit_merge.dart';
import 'package:sabtawya/data/models/child.dart';

ChildVisitLog _log(String id, String type, String date, String? by,
        {String child = 'c1'}) =>
    ChildVisitLog.fromMap({
      'id': id,
      'child_id': child,
      'visit_type': type,
      'visit_date': date,
      'notes': 'x',
      'created_at': '${date}T10:00:00Z',
      'recorded_by': by,
    });

Child _child({String? phone, String? home}) => Child.fromMap({
      'id': 'c1',
      'class_id': 'k1',
      'full_name': 'مينا',
      'gender': 'boy',
      'last_phone_visit_date': phone,
      'last_home_visit_date': home,
    });

void main() {
  group('existingEntry', () {
    final logs = [
      _log('a', 'phone', '2026-11-10', 'me'),
      _log('b', 'home', '2026-11-10', 'me'),
      _log('c', 'phone', '2026-11-09', 'me'),
      _log('d', 'phone', '2026-11-08', 'other'),
      _log('e', 'phone', '2026-11-10', 'me', child: 'c2'),
    ];

    String? find(String type, DateTime date, {String? me = 'me'}) =>
        VisitMerge.existingEntry(
          logs: logs,
          childId: 'c1',
          visitType: type,
          date: date,
          myId: me,
        );

    test('same child, type, day and writer is updated', () {
      expect(find('phone', DateTime(2026, 11, 10, 18, 30)), 'a');
      expect(find('home', DateTime(2026, 11, 10)), 'b');
    });

    test('another day is a new entry', () {
      expect(find('phone', DateTime(2026, 11, 11)), isNull);
    });

    test("another servant's entry is never reused", () {
      expect(find('phone', DateTime(2026, 11, 8)), isNull);
    });

    test('no signed-in user means insert', () {
      expect(find('phone', DateTime(2026, 11, 10), me: null), isNull);
    });
  });

  group('isLatest', () {
    test('no stored visit: becomes latest', () {
      expect(VisitMerge.isLatest(DateTime(2026, 1, 1), null), isTrue);
    });
    test('same day or newer: latest', () {
      final stored = DateTime(2026, 11, 10);
      expect(VisitMerge.isLatest(DateTime(2026, 11, 10, 23), stored), isTrue);
      expect(VisitMerge.isLatest(DateTime(2026, 11, 11), stored), isTrue);
    });
    test('back-dated visit does not replace a newer one', () {
      expect(
        VisitMerge.isLatest(DateTime(2026, 11, 1), DateTime(2026, 11, 10)),
        isFalse,
      );
    });
  });

  group('contactedSince', () {
    final lastPresent = DateTime(2026, 10, 24);
    test('no visit at all: not contacted', () {
      expect(VisitMerge.contactedSince(_child(), lastPresent), isFalse);
    });
    test('visit before the last attendance: not contacted', () {
      expect(
        VisitMerge.contactedSince(_child(phone: '2026-10-20'), lastPresent),
        isFalse,
      );
    });
    test('phone or home visit after it: contacted', () {
      expect(
        VisitMerge.contactedSince(_child(phone: '2026-11-08'), lastPresent),
        isTrue,
      );
      expect(
        VisitMerge.contactedSince(_child(home: '2026-11-01'), lastPresent),
        isTrue,
      );
    });
    test('never attended but visited: contacted', () {
      expect(VisitMerge.contactedSince(_child(phone: '2026-11-08'), null),
          isTrue);
    });
  });
}
