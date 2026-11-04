import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/models/competition.dart';
import 'package:sabtawya/data/services/excel_service.dart';

Child _child(String id, String name) => Child(
      id: id,
      classId: 'c1',
      fullName: name,
      gender: Gender.boy,
      isActive: true,
    );

Competition _comp(String id, String title, DateTime d) => Competition(
      id: id,
      title: title,
      weekDate: d,
      maxMark: 10,
      createdBy: 'u',
      createdAt: d,
    );

CompetitionMark _mark(String comp, String child, int mark) => CompetitionMark(
      id: '$comp$child',
      competitionId: comp,
      childId: child,
      mark: mark,
      markedBy: 'u',
      markedAt: DateTime(2026),
    );

void main() {
  test('cumulative sheet is ordered by total, highest first, with one sheet '
      'per competition', () {
    final bytes = ExcelService.competitionsWorkbook(
      competitions: [
        _comp('a', 'الأولى', DateTime(2026, 10, 10)),
        _comp('b', 'الثانية', DateTime(2026, 10, 17)),
      ],
      children: [_child('1', 'أ'), _child('2', 'ب'), _child('3', 'ج')],
      marks: [
        _mark('a', '1', 5),
        _mark('b', '1', 4),
        _mark('a', '2', 9),
        _mark('b', '2', 8),
        _mark('a', '3', 9),
      ],
      classNameOf: (_) => 'فصل',
    );
    final book = Excel.decodeBytes(bytes);
    expect(book.tables.length, 3);
    final rows = book.tables['المجموع التراكمي']!.rows;
    String name(int r) => rows[r][1]!.value.toString();
    expect(name(1), 'ب'); // 17
    expect(name(2), 'أ'); // 5 + 4 = 9, tied with ج, so by name
    expect(name(3), 'ج'); // 9
  });

  test('exports are formatted as a table: styled header and banded body', () {
    final bytes = ExcelService.childrenTemplate();
    final sheet = Excel.decodeBytes(bytes).tables.values.first;
    final header = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .cellStyle;
    expect(header?.isBold, isTrue);
    expect(header?.backgroundColor.colorHex, 'FF1F3A5F');
    final body = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        .cellStyle;
    expect(body?.topBorder.borderStyle, BorderStyle.Thin);
  });
}
