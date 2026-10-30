import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/app_date_utils.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';

final _year = AttendanceYear(
  id: 'year-1',
  name: '2026 - 2027',
  startDate: DateTime(2026, 10, 24),
  endDate: DateTime(2027, 9, 25),
  sessionWeekday: 6,
  pointsSundaySchool: 5,
  pointsVespers: 5,
  pointsMass: 5,
  pointsConfession: 5,
  maxPointsPerSession: 20,
  isCurrent: true,
);

Child _child(String name) => Child(
      id: name,
      classId: 'class-1',
      fullName: name,
      gender: Gender.boy,
      isActive: true,
    );

AttendanceEntry _entry({AttendanceRecord? record}) => AttendanceEntry.from(
      child: _child('مينا'),
      record: record,
      year: _year,
    );

void main() {
  group('AttendanceEntry', () {
    test('a child with no record starts unmarked and not recorded', () {
      final entry = _entry();

      expect(entry.isRecorded, isFalse);
      expect(entry.isPresent, isFalse);
      expect(entry.score, 0);
      expect(entry.maxScore, 20);
    });

    test('each activity adds its own points', () {
      final entry = _entry()..sundaySchool = true;
      expect(entry.score, 5);

      entry.vespers = true;
      expect(entry.score, 10);

      entry.mass = true;
      expect(entry.score, 15);

      entry.confession = true;
      expect(entry.score, 20);
      expect(entry.isPresent, isTrue);
    });

    test('it carries the audit trail of the saved record', () {
      final entry = _entry(
        record: AttendanceRecord(
          sessionId: 'session-1',
          childId: 'مينا',
          sundaySchool: true,
          vespers: false,
          mass: false,
          confession: false,
          score: 5,
          maxScore: 20,
          updatedByName: 'أبانوب',
          updatedAt: DateTime(2026, 10, 24, 11),
        ),
      );

      expect(entry.isRecorded, isTrue);
      expect(entry.updatedByName, 'أبانوب');
      expect(entry.score, 5);
    });

    test('the upsert payload carries the flags only, never a score', () {
      final entry = _entry()
        ..sundaySchool = true
        ..mass = true;

      final payload = entry.toUpsertMap('session-1');

      expect(payload, <String, dynamic>{
        'session_id': 'session-1',
        'child_id': 'مينا',
        'sunday_school': true,
        'vespers': false,
        'mass': true,
        'confession': false,
      });
    });

    test('clone and sameMarksAs detect an edit', () {
      final entry = _entry();
      final before = entry.clone();

      expect(entry.sameMarksAs(before), isTrue);

      entry.vespers = true;
      expect(entry.sameMarksAs(before), isFalse);
      expect(before.vespers, isFalse);
    });
  });

  group('AttendanceSheet', () {
    test('totals come from the entries and the year configuration', () {
      final sheet = AttendanceSheet(
        session: AttendanceSession(
          id: 'session-1',
          yearId: _year.id,
          classId: 'class-1',
          sessionDate: DateTime(2026, 10, 24),
          isLocked: false,
        ),
        year: _year,
        entries: <AttendanceEntry>[
          _entry()..sundaySchool = true,
          _entry(
            record: AttendanceRecord(
              sessionId: 'session-1',
              childId: 'مريم',
              sundaySchool: false,
              vespers: false,
              mass: false,
              confession: false,
              score: 0,
              maxScore: 20,
            ),
          ),
        ],
      );

      expect(sheet.totalScore, 5);
      expect(sheet.maxScore, 40);
      expect(sheet.presentCount, 1);
      // A child marked absent still counts as recorded.
      expect(sheet.recordedCount, 1);
    });
  });

  group('AppDateUtils', () {
    test('formats dates in Arabic with Latin digits', () {
      expect(AppDateUtils.formatDate(DateTime(2026, 10, 24)), '24 أكتوبر 2026');
      expect(
        AppDateUtils.formatDayDate(DateTime(2026, 10, 24)),
        'السبت، 24 أكتوبر 2026',
      );
    });

    test('the attendance year starts and ends on a Saturday', () {
      expect(_year.startDate.weekday, DateTime.saturday);
      expect(_year.endDate.weekday, DateTime.saturday);
    });

    test('lastSaturday returns the day itself when it is a Saturday', () {
      final saturday = DateTime(2026, 10, 24);

      expect(AppDateUtils.lastSaturday(saturday), saturday);
      expect(
        AppDateUtils.lastSaturday(DateTime(2026, 10, 28)),
        DateTime(2026, 10, 24),
      );
    });

    test('toIsoDate drops the time', () {
      expect(AppDateUtils.toIsoDate(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    });
  });
}
