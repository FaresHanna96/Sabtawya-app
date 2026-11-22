import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/repositories/lesson_repository.dart';
import 'package:sabtawya/features/attendance/attendance_screen.dart';
import 'package:sabtawya/features/attendance/break_sheet.dart';

final _year = AttendanceYear(
  id: 'y',
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

AttendanceEntry _entry(String id, {bool mass = false}) => AttendanceEntry.from(
      child: Child(
        id: id,
        classId: 'c',
        fullName: id,
        gender: Gender.boy,
        isActive: true,
      ),
      year: _year,
      record: AttendanceRecord(
        sessionId: 's',
        childId: id,
        sundaySchool: false,
        vespers: false,
        mass: mass,
        confession: false,
        score: 0,
        maxScore: 20,
      ),
    );

/// Opens the sheet from a button and hands back what it returned.
Future<BreakChoice?> _open(
  WidgetTester tester, {
  LessonBreak? current,
  bool hasRecords = false,
  required Future<void> Function() interact,
}) async {
  BreakChoice? result;
  var closed = false;
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await showBreakSheet(
                  context,
                  date: DateTime(2026, 11, 14),
                  current: current,
                  hasRecords: hasRecords,
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await interact();
  await tester.pumpAndSettle();
  expect(closed, isTrue);
  return result;
}

void main() {
  group('saving with nobody ticked asks first', () {
    test('nobody present', () {
      expect(nobodyPresent([_entry('a'), _entry('b')]), isTrue);
    });

    test('one present is a normal save', () {
      expect(nobodyPresent([_entry('a'), _entry('b', mass: true)]), isFalse);
    });

    test('an empty class is not asked about', () {
      expect(nobodyPresent(const []), isFalse);
    });
  });

  test('a break from before the kind column reads as a holiday', () {
    expect(LessonBreakKind.fromWire(null), LessonBreakKind.holiday);
    expect(LessonBreakKind.fromWire('activity'), LessonBreakKind.activity);
  });

  group('the admin marks a Saturday', () {
    testWidgets('as نشاط ترفيهي, postponing the lessons by default',
        (tester) async {
      final c = await _open(tester, interact: () async {
        await tester.tap(find.text(AppStrings.save));
      });
      expect(c?.kind, LessonBreakKind.activity);
      expect(c?.shift, isTrue);
      // A normal day is offered only when the day is already a break.
      expect(find.text(AppStrings.breakNone), findsNothing);
    });

    testWidgets('as إجازة, keeping the lessons in place', (tester) async {
      final c = await _open(tester, interact: () async {
        await tester.tap(find.text(AppStrings.breakHoliday));
        await tester.pump();
        await tester.tap(find.byType(Switch));
        await tester.pump();
        await tester.tap(find.text(AppStrings.save));
      });
      expect(c?.kind, LessonBreakKind.holiday);
      expect(c?.shift, isFalse);
    });

    testWidgets('back to a normal day', (tester) async {
      final c = await _open(
        tester,
        current: const LessonBreak(
          kind: LessonBreakKind.activity,
          shift: true,
        ),
        hasRecords: true,
        interact: () async {
          expect(find.text(AppStrings.breakHasRecords), findsOneWidget);
          await tester.tap(find.text(AppStrings.breakNone));
          await tester.pump();
          await tester.tap(find.text(AppStrings.save));
        },
      );
      expect(c, isNotNull);
      expect(c!.kind, isNull);
    });
  });
}
