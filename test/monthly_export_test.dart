import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/features/excel/export_screen.dart';

ChildMonthlyReport _row(DateTime month, int held) => ChildMonthlyReport(
      childId: 'c',
      childName: 'x',
      gender: Gender.boy,
      classId: 'k',
      className: 'k',
      yearId: 'y',
      monthStart: month,
      sessionsTotal: held,
      sessionsAttended: 0,
      points: 0,
      maxPoints: 0,
      percentage: 0,
      childIsActive: true,
    );

void main() {
  test('month choices: held months up to now, oldest first, no repeats', () {
    final rows = [
      _row(DateTime(2026, 11), 1),
      _row(DateTime(2026, 9), 1),
      _row(DateTime(2026, 10), 4),
      _row(DateTime(2026, 10), 4), // a second child, same month
      _row(DateTime(2026, 12), 4), // not yet
      _row(DateTime(2026, 8), 0), // nothing held
    ];
    expect(
      ExportScreen.monthsWithData(rows, DateTime(2026, 11, 13)),
      [DateTime(2026, 9), DateTime(2026, 10), DateTime(2026, 11)],
    );
  });
}
