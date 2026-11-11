import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/event.dart';
import 'package:sabtawya/data/services/excel_service.dart';

ChildEventBalance _b(String id, String name, String cls, double paid) =>
    ChildEventBalance(
      eventId: 'e',
      childId: id,
      childName: name,
      classId: cls,
      cost: 50,
      totalPaid: paid,
      remaining: 50 - paid,
    );

void main() {
  final bytes = ExcelService.eventWorkbook(
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
  );
  final book = Excel.decodeBytes(bytes);

  List<List<String>> rows(String sheet) => [
        for (final r in book.tables[sheet]!.rows)
          [for (final c in r) '${c?.value ?? ''}'],
      ];

  test('one sheet per tab, in the screen order', () {
    expect(book.tables.keys.toList(), [
      AppStrings.all,
      AppStrings.bookedTab,
      AppStrings.partialPay,
      AppStrings.paidInFull,
      AppStrings.notPaidTab,
    ]);
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
}
