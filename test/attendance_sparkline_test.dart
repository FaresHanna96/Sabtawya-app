import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/children/attendance_sparkline.dart';

ChildSessionScore _s(String date, {int score = 15, int max = 15}) =>
    ChildSessionScore(
      sessionId: date,
      sessionDate: DateTime.parse(date),
      className: 'c',
      childId: 'k',
      childName: 'k',
      gender: Gender.boy,
      sundaySchool: score > 0,
      vespers: false,
      mass: false,
      confession: false,
      score: score,
      maxScore: max,
    );

void main() {
  final today = DateTime(2026, 11, 18);

  test('keeps the last Saturdays, oldest first, never future ones', () {
    final all = [
      for (var d = 1; d <= 12; d++) _s('2026-10-${d.toString().padLeft(2, '0')}'),
      _s('2026-12-05'),
    ];
    final shown = AttendanceSparkline.lastSessions(all.reversed.toList(), today);
    expect(shown, hasLength(10));
    expect(shown.first.sessionDate, DateTime(2026, 10, 3));
    expect(shown.last.sessionDate, DateTime(2026, 10, 12));
  });

  test('an absence keeps a short stub, a full score a full bar', () {
    expect(AttendanceSparkline.barFraction(_s('2026-10-01', score: 0)), 0.12);
    expect(AttendanceSparkline.barFraction(_s('2026-10-01')), 1.0);
    expect(AttendanceSparkline.barFraction(_s('2026-10-01', score: 5)),
        closeTo(1 / 3, 0.001));
  });

  testWidgets('draws one bar per Saturday, absent ones red', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AttendanceSparkline(history: [
          _s('2026-10-03'),
          _s('2026-10-10', score: 0),
          _s('2026-10-17'),
        ]),
      ),
    ));
    expect(find.byType(DecoratedBox), findsWidgets);
    expect(find.byKey(ValueKey('bar|${DateTime(2026, 10, 10)}')), findsOneWidget);
  });

  testWidgets('fewer than two Saturdays draws nothing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AttendanceSparkline(history: [_s('2026-10-03')])),
    ));
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.text('آخر سبوت'), findsNothing);
  });
}
