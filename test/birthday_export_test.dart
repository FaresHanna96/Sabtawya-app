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

  test('children: one sheet, rows in the order given, no role column', () {
    final sheet = _read(ExcelService.birthdaysWorkbook(rows, servants: false));
    expect(sheet.first, [
      AppStrings.dayOfMonth,
      AppStrings.month,
      AppStrings.personName,
      AppStrings.classLabel,
      AppStrings.birthDate,
      AppStrings.turningAgeColumn,
      AppStrings.mobile,
    ]);
    expect(sheet.length, 3);
    expect(sheet[1].take(6).toList(),
        ['1', 'نوفمبر', 'جويس ياسر', '5 بنات', '2015-11-01', '11']);
    expect(sheet[2][2], 'يؤانس بسام');
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
    expect(sheet.first[3], AppStrings.role);
    expect(sheet[1][3], 'خادمة');
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
