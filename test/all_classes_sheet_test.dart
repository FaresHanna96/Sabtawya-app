import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/services/excel_service.dart';

final _year = AttendanceYear(
  id: 'y',
  name: '2026 - 2027',
  startDate: DateTime(2026, 9, 26),
  endDate: DateTime(2027, 9, 25),
  sessionWeekday: 6,
  pointsSundaySchool: 5,
  pointsVespers: 5,
  pointsMass: 5,
  pointsConfession: 5,
  maxPointsPerSession: 20,
  isCurrent: true,
);

({String className, AttendanceEntry entry}) _row(
  String cls,
  String name, {
  bool came = false,
}) =>
    (
      className: cls,
      entry: AttendanceEntry.from(
        child: Child(
          id: name,
          classId: cls,
          fullName: name,
          gender: Gender.girl,
          isActive: true,
        ),
        record: AttendanceRecord(
          sessionId: 's-$cls',
          childId: name,
          sundaySchool: came,
          vespers: false,
          mass: false,
          confession: false,
          score: came ? 5 : 0,
          maxScore: 20,
        ),
        year: _year,
      ),
    );

void main() {
  test('every class in one file: main sheet with a class column, a sheet each',
      () {
    final bytes = ExcelService.attendanceSheetsWorkbook(
      sessionDate: DateTime(2026, 11, 7),
      rows: [
        _row('5 بنات', 'مريم', came: true),
        _row('3 ولاد', 'مينا'),
        _row('5 بنات', 'سارة'),
      ],
    );
    final book = Excel.decodeBytes(bytes);
    final main = book.tables[AppStrings.attendanceTitle]!.rows;
    String cell(List<Data?> r, int i) => r[i]?.value?.toString() ?? '';

    expect(cell(main[0], 0), AppStrings.classLabel);
    // 3 ولاد sorts before 5 بنات, as the app lists classes.
    expect(main.skip(1).map((r) => cell(r, 0)).toList(),
        ['3 ولاد', '5 بنات', '5 بنات']);
    expect(cell(main[2], 1), 'مريم');
    expect(cell(main[2], 3), '5'); // Sunday school points
    // A sheet per class besides the main one.
    expect(book.tables.length, 3);
  });
}
