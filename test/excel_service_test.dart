import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/services/excel_service.dart';

/// Builds a one-sheet workbook from rows of plain text.
List<int> _workbook(List<List<String>> rows) {
  final book = Excel.createExcel();
  final sheet = book['Sheet1'];
  for (final row in rows) {
    sheet.appendRow(row.map<CellValue?>(TextCellValue.new).toList());
  }
  return book.encode()!;
}

void main() {
  group('parseChildren', () {
    test('reads the file produced by the template', () {
      final result = ExcelService.parseChildren(ExcelService.childrenTemplate());

      expect(result.isFailure, isFalse);
      final row = result.rows.single;
      expect(row.name, 'مينا جورج');
      expect(row.gender, Gender.boy);
      expect(row.birthDate, DateTime(2015, 3, 14));
      expect(row.confessionFather, 'أبونا يوسف');
      expect(row.code, 'C-001');
      expect(row.hasErrors, isFalse);
    });

    test('matches headers that differ by hamza, ة, or ى', () {
      final bytes = _workbook([
        <String>['الإسم', 'النوع', 'اسم الأم', 'المدرسة'],
        <String>['مريم', 'بنت', 'سارة', 'مدرسة النيل'],
      ]);

      final result = ExcelService.parseChildren(bytes);

      expect(result.isFailure, isFalse);
      final row = result.rows.single;
      expect(row.name, 'مريم');
      expect(row.gender, Gender.girl);
      expect(row.motherName, 'سارة');
      expect(row.school, 'مدرسة النيل');
    });

    test('accepts English headers from an older spreadsheet', () {
      final bytes = _workbook([
        <String>['Name', 'Gender', 'Mobile', 'Code'],
        <String>['Mina', 'boy', '01000000000', 'C-9'],
      ]);

      final row = ExcelService.parseChildren(bytes).rows.single;

      expect(row.name, 'Mina');
      expect(row.gender, Gender.boy);
      expect(row.mobile, '01000000000');
      expect(row.code, 'C-9');
    });

    test('finds the header even when the sheet starts with a title row', () {
      final bytes = _workbook([
        <String>['كشف الفصل الأول'],
        <String>[''],
        <String>['اسم المخدوم', 'النوع'],
        <String>['مينا', 'ولد'],
      ]);

      final result = ExcelService.parseChildren(bytes);

      expect(result.rows.single.name, 'مينا');
      // Row numbers stay 1-based so they match what the user sees in Excel.
      expect(result.rows.single.rowNumber, 4);
    });

    test('flags a missing name, an unreadable gender, and a bad mobile', () {
      final bytes = _workbook([
        <String>['اسم المخدوم', 'النوع', 'موبايل المخدوم'],
        <String>['', 'ولد', '01000000000'],
        <String>['مينا', 'غير معروف', '01000000000'],
        <String>['مريم', 'بنت', '12'],
      ]);

      final rows = ExcelService.parseChildren(bytes).rows;

      expect(rows.length, 3);
      expect(rows[0].hasErrors, isTrue);
      expect(rows[1].hasErrors, isTrue);
      expect(rows[2].hasErrors, isTrue);
      expect(rows[2].parseErrors.single, contains('موبايل'));
    });

    test('skips blank rows instead of reporting them as errors', () {
      final bytes = _workbook([
        <String>['اسم المخدوم', 'النوع'],
        <String>['مينا', 'ولد'],
        <String>['', ''],
        <String>['مريم', 'بنت'],
      ]);

      final rows = ExcelService.parseChildren(bytes).rows;

      expect(rows.length, 2);
      expect(rows.every((row) => !row.hasErrors), isTrue);
    });

    test('reports a file whose columns it cannot recognise', () {
      final bytes = _workbook([
        <String>['foo', 'bar'],
        <String>['1', '2'],
      ]);

      expect(ExcelService.parseChildren(bytes).isFailure, isTrue);
    });

    test('rejects bytes that are not a workbook', () {
      expect(
        ExcelService.parseChildren(<int>[1, 2, 3, 4]).isFailure,
        isTrue,
      );
    });
  });

  group('ImportRow.applyTo', () {
    final existing = Child(
      id: 'child-1',
      classId: 'class-1',
      fullName: 'مينا جورج',
      gender: Gender.boy,
      isActive: true,
      school: 'مدرسة النيل',
      notes: 'ملاحظة قديمة',
      photoPath: 'child-1/1.jpg',
    );

    test('a blank cell keeps the stored value', () {
      final row = ImportRow(rowNumber: 2, name: 'مينا جورج', school: 'مدرسة جديدة');

      final merged = row.applyTo(existing, 'class-1');

      expect(merged.school, 'مدرسة جديدة');
      expect(merged.notes, 'ملاحظة قديمة');
      expect(merged.id, 'child-1');
    });

    test('an update can move the child to the selected class', () {
      final row = ImportRow(rowNumber: 2, name: 'مينا جورج');

      expect(row.applyTo(existing, 'class-2').classId, 'class-2');
    });

    test('resetResolution clears the verdict but keeps the parse errors', () {
      final row = ImportRow(rowNumber: 2, name: '')
        ..parseErrors.add('name missing')
        ..importErrors.add('duplicate')
        ..note = 'skipped'
        ..action = ImportAction.update
        ..movesClass = true;

      row.resetResolution();

      expect(row.parseErrors, hasLength(1));
      expect(row.importErrors, isEmpty);
      expect(row.note, isNull);
      expect(row.action, ImportAction.skip);
      expect(row.movesClass, isFalse);
      expect(row.hasErrors, isTrue);
    });
  });
}
