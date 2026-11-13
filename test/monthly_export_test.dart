import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/data/services/excel_service.dart';
import 'package:sabtawya/data/services/file_service.dart';
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

  test('file name: the months ticked, or كل الشهور when all are', () {
    final all = [DateTime(2026, 9), DateTime(2026, 10), DateTime(2026, 11)];
    expect(ExportScreen.monthsLabel({...all}, all), AppStrings.allMonths);
    expect(
      ExportScreen.monthsLabel({DateTime(2026, 11), DateTime(2026, 9)}, all),
      'سبتمبر 2026، نوفمبر 2026',
    );
  });

  test('Excel file names carry no export date', () {
    expect(FileService.xlsxName('الحضور الشهري - 5 ولاد'),
        'الحضور الشهري - 5 ولاد.xlsx');
    expect(FileService.xlsxName('a/b:c'), 'a-b-c.xlsx');
  });

  test('workbook: one row per child, the months added together', () {
    ChildMonthlyReport r(String name, int month, int held, int came, int pts) =>
        ChildMonthlyReport(
          childId: name,
          childName: name,
          gender: Gender.boy,
          classId: 'k',
          className: '5 ولاد',
          yearId: 'y',
          monthStart: DateTime(2026, month),
          sessionsTotal: held,
          sessionsAttended: came,
          points: pts,
          maxPoints: held * 20,
          percentage: 0,
          childIsActive: true,
        );
    final bytes = ExcelService.monthlyWorkbook([
      r('بيشوي', 10, 5, 1, 5),
      r('مينا', 10, 5, 4, 30),
      r('بيشوي', 11, 1, 0, 0),
      r('مينا', 11, 1, 1, 5),
    ]);
    final rows = Excel.decodeBytes(bytes).tables.values.first.rows;
    String c(int row, int col) => rows[row][col]?.value?.toString() ?? '';

    expect(rows.length, 3); // header + 2 children, not 4 month rows
    expect(rows[0].length, 7); // no per-month columns
    // Months added together; best attendance first: مينا 5 of 6.
    expect([c(1, 1), c(1, 3), c(1, 4), c(1, 5)], ['مينا', '5', '6', '35']);
    expect(double.parse(c(1, 6)), 83.3);
    expect([c(2, 1), c(2, 3), c(2, 4)], ['بيشوي', '1', '6']);
  });
}
