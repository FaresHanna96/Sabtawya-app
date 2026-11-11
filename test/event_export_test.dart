import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/event.dart';
import 'package:sabtawya/data/services/excel_service.dart';

ChildEventBalance _b(String id, String name, String cls, double paid,
        {bool reserved = false}) =>
    ChildEventBalance(
      eventId: 'e',
      childId: id,
      childName: name,
      classId: cls,
      cost: 50,
      totalPaid: paid,
      remaining: 50 - paid,
      reserved: reserved,
    );

void main() {
  Excel build(String tab, [List<String>? tabs]) =>
      Excel.decodeBytes(ExcelService.eventWorkbook(
        balances: [
          _b('1', 'مينا', 'k2', 50),
          _b('2', 'بولا', 'k1', 20),
          _b('3', 'ايرينى', 'k1', 0),
          _b('4', 'كيرلس', 'k2', 0),
        ],
        methodByChild: {
          '1': {'cash': 40, 'tayo': 10},
          '2': {'cash': 20},
        },
        phones: {'1': '0100'},
        classNameOf: (id) => id == 'k1' ? 'أ' : 'ب',
        tabs: tabs ?? [tab],
      ));

  List<List<String>> rows(String sheet) => [
        for (final r in build(sheet).tables[sheet]!.rows)
          [for (final c in r) '${c?.value ?? ''}'],
      ];

  test('several chosen statuses give one sheet each, in screen order', () {
    final book = build('', [AppStrings.notPaidTab, AppStrings.bookedTab]);
    expect(book.tables.keys.toList(),
        [AppStrings.bookedTab, AppStrings.notPaidTab]);
  });

  test('counts per status match the tabs', () {
    final counts = ExcelService.eventTabCounts([
      _b('1', 'a', 'k', 50),
      _b('2', 'b', 'k', 20),
      _b('3', 'c', 'k', 0),
    ]);
    expect(counts, {
      AppStrings.all: 3,
      AppStrings.bookedTab: 2,
      AppStrings.partialPay: 1,
      AppStrings.paidInFull: 1,
      AppStrings.notPaidTab: 1,
    });
  });

  test('the file holds only the chosen tab', () {
    for (final tab in ExcelService.eventTabs) {
      expect(build(tab).tables.keys.toList(), [tab]);
    }
    expect(ExcelService.eventTabs.length, 5);
  });

  test('each sheet holds the children of its tab plus header and totals', () {
    expect(rows(AppStrings.all).length, 4 + 2);
    expect(rows(AppStrings.bookedTab).length, 2 + 2);
    expect(rows(AppStrings.partialPay).length, 1 + 2);
    expect(rows(AppStrings.paidInFull).length, 1 + 2);
    expect(rows(AppStrings.notPaidTab).length, 2 + 2);
    expect(rows(AppStrings.partialPay)[1][1], 'بولا');
    expect(rows(AppStrings.paidInFull)[1][1], 'مينا');
  });

  test('rows are grouped by class then name, with status and split', () {
    final all = rows(AppStrings.all);
    expect([for (final r in all.sublist(1, 5)) r[1]],
        ['ايرينى', 'بولا', 'كيرلس', 'مينا']);
    final mina = all[4];
    expect(mina[3], '0100');
    expect(double.parse(mina[5]), 50);
    expect(double.parse(mina[6]), 40);
    expect(double.parse(mina[7]), 10);
    expect(double.parse(mina[8]), 0);
    expect(mina[9], AppStrings.paidInFull);
    expect(all[1][9], AppStrings.notPaidTab);
    expect(all[2][9], AppStrings.partialPay);
  });

  test('totals row sums the sheet', () {
    final total = rows(AppStrings.all).last;
    expect(total[1], '${AppStrings.total} (4)');
    expect(double.parse(total[4]), 200);
    expect(double.parse(total[5]), 70);
    expect(double.parse(total[6]), 60);
    expect(double.parse(total[7]), 10);
    expect(double.parse(total[8]), 130);
  });

  group('reserved without paying', () {
    final reserved = _b('5', 'جورج', 'k1', 0, reserved: true);

    test('is in حاجزين and لم يدفع, not in بدأ الدفع or مسدّد', () {
      bool inTab(String t) => ExcelService.eventTabFilter[t]!(reserved);
      expect(inTab(AppStrings.bookedTab), isTrue);
      expect(inTab(AppStrings.notPaidTab), isTrue);
      expect(inTab(AppStrings.partialPay), isFalse);
      expect(inTab(AppStrings.paidInFull), isFalse);
    });

    test('counts include it', () {
      final counts = ExcelService.eventTabCounts(
          [reserved, _b('6', 'x', 'k1', 0), _b('7', 'y', 'k1', 20)]);
      expect(counts[AppStrings.bookedTab], 2);
      expect(counts[AppStrings.notPaidTab], 2);
    });

    test('its Excel status says reserved, unpaid', () {
      final book = Excel.decodeBytes(ExcelService.eventWorkbook(
        balances: [reserved],
        methodByChild: const {},
        phones: const {},
        classNameOf: (_) => 'أ',
        tabs: const [AppStrings.bookedTab],
      ));
      final row = book.tables[AppStrings.bookedTab]!.rows[1];
      expect('${row[9]?.value}', AppStrings.reservedUnpaidStatus);
    });
  });
}
