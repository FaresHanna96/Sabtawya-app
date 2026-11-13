import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/services/excel_service.dart';
import 'package:sabtawya/features/children/birthday_screen.dart';

List<List<String>> _read(List<int> bytes) {
  final book = Excel.decodeBytes(bytes);
  final sheet = book.tables[AppStrings.birthdaysTitle]!;
  return [
    for (final row in sheet.rows)
      [for (final cell in row) cell?.value?.toString() ?? ''],
  ];
}

void main() {
  final rows = [
    BirthdayRow(
      name: 'جويس ياسر',
      birthDate: DateTime(2015, 11, 1),
      turningAge: 11,
      className: '5 بنات',
      mobile: '01200000000',
    ),
    BirthdayRow(
      name: 'يؤانس بسام',
      birthDate: DateTime(2016, 11, 11),
      turningAge: 10,
      className: '3 ولاد',
    ),
  ];

  test('children: class first, grouped by class, no role column', () {
    final sheet = _read(ExcelService.birthdaysWorkbook(rows, servants: false));
    expect(sheet.first, [
      AppStrings.classLabel,
      AppStrings.dayOfMonth,
      AppStrings.month,
      AppStrings.personName,
      AppStrings.birthDate,
      AppStrings.turningAgeColumn,
      AppStrings.mobile,
    ]);
    expect(sheet.length, 3);
    // 3 ولاد comes before 5 بنات, as the app lists classes.
    expect(sheet[1].take(6).toList(),
        ['3 ولاد', '11', 'نوفمبر', 'يؤانس بسام', '2016-11-11', '10']);
    expect(sheet[2][3], 'جويس ياسر');
  });

  test('servants: adds the role column after the name', () {
    final sheet = _read(ExcelService.birthdaysWorkbook([
      BirthdayRow(
        name: 'مارتينا',
        birthDate: DateTime(1999, 5, 3),
        turningAge: 27,
        role: 'خادمة',
      ),
    ], servants: true));
    expect(sheet.first[4], AppStrings.role);
    expect(sheet[1][4], 'خادمة');
  });

  group('turningAge', () {
    final today = DateTime(2026, 11, 12, 18, 30);
    test('birthday later this year: the age reached this year', () {
      expect(turningAge(DateTime(2015, 12, 1), today), 11);
    });
    test('birthday today: the age reached today', () {
      expect(turningAge(DateTime(2015, 11, 12), today), 11);
    });
    test('birthday already passed: the age reached next year', () {
      expect(turningAge(DateTime(2015, 11, 1), today), 12);
    });
  });
}
