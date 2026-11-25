import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/children/child_attendance_log.dart';

ChildSessionScore _s(DateTime d, {bool mass = false, bool vespers = false}) =>
    ChildSessionScore(
      sessionId: 's${d.millisecondsSinceEpoch}',
      sessionDate: d,
      className: 'ف',
      childId: 'k',
      childName: 'م',
      gender: Gender.girl,
      sundaySchool: true,
      vespers: vespers,
      mass: mass,
      confession: false,
      score: 5,
      maxScore: 20,
    );

void main() {
  final today = DateTime(2026, 11, 25);
  List<LogMonth> months(List<ChildSessionScore> h) => LogMonth.build(
        history: h,
        sessionDates: [for (final x in h) x.sessionDate],
        today: today,
      );

  test('a Saturday marked ahead is not the last time', () {
    final m = months([
      _s(DateTime(2026, 11, 21), mass: true),
      _s(DateTime(2026, 11, 28), mass: true), // in the future
    ]);
    expect(LogActivity.mass.lastDone(m, DateTime(2026, 11, 28), today),
        DateTime(2026, 11, 21));
  });

  test('a database date up to today is used as it is', () {
    final m = months([_s(DateTime(2026, 11, 21))]);
    expect(LogActivity.mass.lastDone(m, DateTime(2026, 5, 30), today),
        DateTime(2026, 5, 30));
    expect(LogActivity.mass.lastDone(m, today, today), today);
  });

  test('no database date: nothing, as before', () {
    final m = months([_s(DateTime(2026, 11, 21), mass: true)]);
    expect(LogActivity.mass.lastDone(m, null, today), isNull);
  });

  test('a future database date alone gives nothing', () {
    expect(LogActivity.mass.lastDone(const [], DateTime(2026, 11, 28), today),
        isNull);
  });
}
