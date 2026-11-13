import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/services/excel_service.dart';

String _file(List<int> xlsx, String name) => utf8.decode(
    ZipDecoder().decodeBytes(xlsx).findFile(name)!.content as List<int>);

List<int> _birthdays() => ExcelService.birthdaysWorkbook([
      BirthdayRow(
        name: 'يؤانس بسام',
        birthDate: DateTime(2016, 11, 11),
        turningAge: 10,
        className: '5 ولاد',
      ),
      BirthdayRow(
        name: 'جويس ياسر',
        birthDate: DateTime(2015, 11, 1),
        turningAge: 11,
        className: '3 بنات',
      ),
      BirthdayRow(
        name: 'مينا عادل',
        birthDate: DateTime(2015, 11, 3),
        turningAge: 11,
        className: '3 ولاد',
      ),
    ], servants: false);

void main() {
  test('columnLetter', () {
    expect(ExcelService.columnLetter(0), 'A');
    expect(ExcelService.columnLetter(7), 'H');
    expect(ExcelService.columnLetter(25), 'Z');
    expect(ExcelService.columnLetter(26), 'AA');
  });

  test('class names sort as the app lists them', () {
    final names = ['5 بنات', '3 بنات', 'خدمة', '5 ولاد', '3 ولاد']
      ..sort(ExcelService.compareClassNames);
    expect(names, ['3 ولاد', '3 بنات', '5 ولاد', '5 بنات', 'خدمة']);
  });

  test('every sheet gets filter buttons on its header row', () {
    final xlsx = _birthdays();
    final workbook = _file(xlsx, 'xl/workbook.xml');
    expect(workbook, contains('_xlnm._FilterDatabase'));

    final book = Excel.decodeBytes(xlsx);
    // The whole list plus one sheet per class.
    expect(book.tables.keys.toList(), [
      AppStrings.birthdaysTitle,
      '3 ولاد',
      '3 بنات',
      '5 ولاد',
    ]);
    final sheets = ZipDecoder()
        .decodeBytes(xlsx)
        .files
        .where((f) => f.name.startsWith('xl/worksheets/sheet'))
        .map((f) => utf8.decode(f.content as List<int>))
        .toList();
    expect(sheets, hasLength(4));
    for (final xml in sheets) {
      expect(xml, contains('<autoFilter ref="A1:'));
    }
    // 1 header + 3 children, 7 columns (A-G) on the whole list.
    expect(sheets.any((x) => x.contains('<autoFilter ref="A1:G4"/>')), isTrue);
  });

  test('the whole list is ordered by class, with no separator rows', () {
    final book = Excel.decodeBytes(_birthdays());
    final rows = book.tables[AppStrings.birthdaysTitle]!.rows;
    final classes = [for (final r in rows.skip(1)) '${r[0]?.value}'];
    expect(classes, ['3 ولاد', '3 بنات', '5 ولاد']);
  });

  test('one class: a single sheet', () {
    final xlsx = ExcelService.birthdaysWorkbook([
      BirthdayRow(
        name: 'جويس ياسر',
        birthDate: DateTime(2015, 11, 1),
        turningAge: 11,
        className: '5 بنات',
      ),
    ], servants: false);
    expect(Excel.decodeBytes(xlsx).tables.keys.toList(),
        [AppStrings.birthdaysTitle]);
  });
}
