import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/servant_activity.dart';
import 'package:sabtawya/data/repositories/servant_activity_repository.dart';
import 'package:sabtawya/features/servant_activities/servant_marks.dart';

final _year = AttendanceYear(
  id: 'year-1',
  name: '2026 - 2027',
  startDate: DateTime(2026, 9, 26),
  endDate: DateTime(2027, 6, 26),
  sessionWeekday: 6,
  pointsSundaySchool: 5,
  pointsVespers: 5,
  pointsMass: 5,
  pointsConfession: 5,
  maxPointsPerSession: 20,
  isCurrent: true,
);

ServantAttendance _mark(String id, String servant, String type) =>
    ServantAttendance(
      id: id,
      servantId: servant,
      activityType: type,
      date: DateTime(2026, 11, 21),
      recordedBy: 'admin',
    );

void main() {
  group('AttendanceYear.contains', () {
    test('both ends are inside the year', () {
      expect(_year.contains(DateTime(2026, 9, 26)), isTrue);
      expect(_year.contains(DateTime(2027, 6, 26, 23, 59)), isTrue);
    });

    test('a day before or after the year is outside', () {
      expect(_year.contains(DateTime(2026, 9, 25, 23, 59)), isFalse);
      expect(_year.contains(DateTime(2027, 6, 27)), isFalse);
    });

    test('last year\'s Saturday is not counted in this year', () {
      expect(_year.contains(DateTime(2025, 11, 22)), isFalse);
    });
  });

  group('ServantActivityRepository helpers', () {
    test('countByType counts each activity and skips blank types', () {
      final counts = ServantActivityRepository.countByType([
        {'activity_type': 'mass'},
        {'activity_type': 'mass'},
        {'activity_type': 'confession'},
        {'activity_type': ''},
        {'activity_type': null},
      ]);
      expect(counts, {'mass': 2, 'confession': 1});
    });

    test('distinctDates counts a Saturday once however many classes met', () {
      // 3 classes on the 14th, 2 on the 21st: two Saturdays, not five.
      final n = ServantActivityRepository.distinctDates([
        {'session_date': '2026-11-14'},
        {'session_date': '2026-11-14'},
        {'session_date': '2026-11-14'},
        {'session_date': '2026-11-21'},
        {'session_date': '2026-11-21'},
      ]);
      expect(n, 2);
    });

    test('isoDate pads and keeps the calendar day', () {
      expect(ServantActivityRepository.isoDate(DateTime(2026, 3, 7, 23, 30)),
          '2026-03-07');
    });
  });

  group('ServantMarks', () {
    test('adding shows at once and takes the saved id', () {
      final marks = ServantMarks();
      final t = marks.begin(
        servantId: 's1',
        type: 'mass',
        date: DateTime(2026, 11, 21),
        recordedBy: 'admin',
      )!;
      expect(t.adding, isTrue);
      expect(marks.find('s1', 'mass'), isNotNull);
      expect(marks.isBusy('s1', 'mass'), isTrue);

      marks.succeed(t, _mark('real-id', 's1', 'mass'));
      expect(marks.find('s1', 'mass')!.id, 'real-id');
      expect(marks.isBusy('s1', 'mass'), isFalse);
    });

    test('a refused add disappears again', () {
      final marks = ServantMarks();
      final t = marks.begin(
        servantId: 's1',
        type: 'mass',
        date: DateTime(2026, 11, 21),
        recordedBy: 'admin',
      )!;
      marks.fail(t);
      expect(marks.find('s1', 'mass'), isNull);
      expect(marks.isBusy('s1', 'mass'), isFalse);
    });

    test('removing hides at once and a refusal brings it back', () {
      final marks = ServantMarks([_mark('a1', 's1', 'confession')]);
      final t = marks.begin(
        servantId: 's1',
        type: 'confession',
        date: DateTime(2026, 11, 21),
        recordedBy: 'admin',
      )!;
      expect(t.adding, isFalse);
      expect(marks.find('s1', 'confession'), isNull);

      marks.fail(t);
      expect(marks.find('s1', 'confession')!.id, 'a1');
    });

    test('a second tap on the same chip waits; other chips do not', () {
      final marks = ServantMarks();
      final date = DateTime(2026, 11, 21);
      expect(
        marks.begin(
            servantId: 's1', type: 'mass', date: date, recordedBy: 'admin'),
        isNotNull,
      );
      expect(
        marks.begin(
            servantId: 's1', type: 'mass', date: date, recordedBy: 'admin'),
        isNull,
      );
      expect(
        marks.begin(
            servantId: 's1', type: 'confession', date: date, recordedBy: 'a'),
        isNotNull,
      );
      expect(
        marks.begin(
            servantId: 's2', type: 'mass', date: date, recordedBy: 'admin'),
        isNotNull,
      );
    });

    test('reset replaces the marks and forgets saves in flight', () {
      final marks = ServantMarks();
      marks.begin(
        servantId: 's1',
        type: 'mass',
        date: DateTime(2026, 11, 21),
        recordedBy: 'admin',
      );
      marks.reset([_mark('b1', 's2', 'mass')]);
      expect(marks.items.single.id, 'b1');
      expect(marks.isBusy('s1', 'mass'), isFalse);
    });
  });
}
