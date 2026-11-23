import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/features/children/child_attendance_log.dart';

ChildSessionScore _score(
  DateTime date, {
  bool ss = false,
  bool v = false,
  bool m = false,
  bool c = false,
}) =>
    ChildSessionScore(
      sessionId: 's-${date.toIso8601String()}',
      sessionDate: date,
      className: 'class',
      childId: 'child',
      childName: 'مينا',
      gender: Gender.boy,
      sundaySchool: ss,
      vespers: v,
      mass: m,
      confession: c,
      score: [ss, v, m, c].where((x) => x).length * 5,
      maxScore: 20,
    );

final _today = DateTime(2026, 11, 21);

// October: 5 Saturdays, only the 3rd recorded (mass). November: the 7th
// present (all four), the 14th absent, the 21st (today) not recorded yet,
// the 28th still to come.
final _sessions = [
  DateTime(2026, 10, 3),
  DateTime(2026, 10, 10),
  DateTime(2026, 10, 17),
  DateTime(2026, 10, 24),
  DateTime(2026, 10, 31),
  DateTime(2026, 11, 7),
  DateTime(2026, 11, 14),
  DateTime(2026, 11, 21),
  DateTime(2026, 11, 28),
];
final _history = [
  _score(DateTime(2026, 10, 3), m: true),
  _score(DateTime(2026, 11, 7), ss: true, v: true, m: true, c: true),
  _score(DateTime(2026, 11, 14)),
];

void main() {
  group('LogMonth.build', () {
    final months = LogMonth.build(
      history: _history,
      sessionDates: _sessions,
      today: _today,
    );

    test('newest month first, newest Saturday first, nothing in the future',
        () {
      expect(months.map((m) => m.month),
          [DateTime(2026, 11), DateTime(2026, 10)]);
      expect(months.first.saturdays.map((s) => s.date.day), [21, 14, 7]);
    });

    test('a Saturday nobody recorded is listed but not counted', () {
      final nov = months.first;
      expect(nov.held, 2);
      expect(nov.attended, 1);
      expect(nov.notRecorded, 1);
      expect(nov.points, 20);
      expect(nov.recorded, hasLength(2));
      expect(nov.ratio, 0.5);

      final oct = months.last;
      expect(oct.saturdays, hasLength(5));
      expect(oct.held, 1);
      expect(oct.notRecorded, 4);
      // Only recorded Saturdays are listed.
      expect(nov.recorded.map((s) => s.date.day), [14, 7]);
    });

    test('a month with nothing recorded has no ratio', () {
      final empty = LogMonth.build(
        history: const [],
        sessionDates: [DateTime(2026, 10, 3)],
        today: _today,
      );
      expect(empty.single.held, 0);
      expect(empty.single.ratio, isNull);
    });

    test('the year totals count each activity over recorded Saturdays', () {
      final t = LogTotals.of(months);
      expect(t.held, 3);
      expect(t.attended, 2);
      expect(t.perActivity[LogActivity.mass], 2);
      expect(t.perActivity[LogActivity.sundaySchool], 1);
    });

    test('a record from the child\'s old class still counts', () {
      final moved = LogMonth.build(
        history: [_score(DateTime(2026, 9, 26), m: true)],
        sessionDates: const [],
        today: _today,
      );
      expect(moved.single.attended, 1);
    });

    test('a no-lesson Saturday is listed but counts for nothing', () {
      // 14 Nov was a نشاط ترفيهي, and an all-absent save exists for it.
      final months = LogMonth.build(
        history: _history,
        sessionDates: _sessions,
        breakDates: {DateTime(2026, 11, 14)},
        today: _today,
      );
      final nov = months.first;
      expect(nov.held, 1); // only the 7th
      expect(nov.attended, 1);
      expect(nov.noLesson, 1);
      expect(nov.notRecorded, 1); // the 21st
      expect(nov.listed.map((s) => s.date.day), [14, 7]);
      expect(nov.listed.first.isBreak, isTrue);
      expect(LogTotals.of(months).held, 2); // 7 Nov and 3 Oct
    });

    test('no Saturdays at all gives no months', () {
      expect(
        LogMonth.build(history: const [], sessionDates: const [], today: _today),
        isEmpty,
      );
    });
  });

  group('ChildAttendanceLog', () {
    Widget app() => MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: ChildAttendanceLog(
                  history: _history,
                  sessionDates: _sessions,
                  lastActivity: ChildLastActivity(
                    childId: 'child',
                    lastMass: DateTime(2026, 11, 7),
                  ),
                  points: 25,
                  today: _today,
                ),
              ),
            ),
          ),
        );

    testWidgets('one card: the summary on top, the months under it',
        (tester) async {
      await tester.pumpWidget(app());
      expect(find.text('ملخص الحضور'), findsOneWidget);
      expect(find.text('سجل الحضور'), findsOneWidget);
      expect(find.text('2/3'), findsWidgets); // attended, and mass
      expect(find.text('25'), findsOneWidget); // points
      expect(find.textContaining('آخر مرة'), findsOneWidget); // mass only
      expect(find.text('لم يحضر بعد'), findsNWidgets(3));

      expect(find.text('نوفمبر 2026'), findsOneWidget);
      expect(find.text('حضر 1 من 2'), findsOneWidget);
      expect(find.text('20 طايو · سبت لم يُسجَّل'), findsOneWidget);
      expect(find.text('5 طايو · 4 سبوت لم تُسجَّل'), findsOneWidget);
    });

    testWidgets('a Saturday nobody recorded is not listed', (tester) async {
      await tester.pumpWidget(app());
      expect(find.text('14 نوفمبر'), findsOneWidget);
      expect(find.text('21 نوفمبر'), findsNothing);
      expect(find.text('لم يُسجَّل'), findsNothing);
    });

    testWidgets('only the newest month starts open; a tap opens another',
        (tester) async {
      await tester.pumpWidget(app());
      expect(find.text('7 نوفمبر'), findsOneWidget);
      expect(find.text('3 أكتوبر'), findsNothing);

      await tester.ensureVisible(find.text('أكتوبر 2026'));
      await tester.tap(find.text('أكتوبر 2026'));
      await tester.pumpAndSettle();
      expect(find.text('3 أكتوبر'), findsOneWidget);
    });

    testWidgets('سجل الحضور folds away under the summary', (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.byKey(const ValueKey('log-history-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('نوفمبر 2026'), findsNothing);
      expect(find.text('ملخص الحضور'), findsOneWidget);
    });

    testWidgets('an absent Saturday says غاب instead of 0/20', (tester) async {
      await tester.pumpWidget(app());
      expect(find.text('غاب'), findsWidgets);
      expect(find.text('0/20'), findsNothing);
    });

    testWidgets('the absent filter lists only absences, with counts',
        (tester) async {
      await tester.pumpWidget(app());
      String countIn(String key) => tester
          .widgetList<Text>(find.descendant(
              of: find.byKey(ValueKey(key)), matching: find.byType(Text)))
          .map((t) => t.data)
          .join(' ');

      // Recorded Saturdays only: 3 in all, 2 present, 1 absent.
      expect(countIn('log-filter-all'), 'الكل 3');
      expect(countIn('log-filter-present'), 'حضر 2');
      expect(countIn('log-filter-absent'), 'غاب 1');

      await tester.tap(find.byKey(const ValueKey('log-filter-absent')));
      await tester.pumpAndSettle();
      expect(find.text('14 نوفمبر'), findsOneWidget);
      expect(find.text('7 نوفمبر'), findsNothing);
      // October has no absence, so it is left out while filtering.
      expect(find.text('أكتوبر 2026'), findsNothing);
    });
  });
}
