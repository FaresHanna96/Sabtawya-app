import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/features/dashboard/quick_action_grid.dart';

List<QuickAction> _actions(int n) => [
      for (var i = 0; i < n; i++)
        QuickAction(
          Icons.star,
          // One long label, so a row has a two-line tile.
          i == 3 ? 'نشاطات ترفيهية طويلة جدا' : 'إجراء $i',
          Colors.teal,
          () {},
        ),
    ];

void main() {
  test('rows are split evenly, never one tile alone', () {
    expect(QuickActionGrid.perRow(3), 3);
    expect(QuickActionGrid.perRow(4), 4);
    expect(QuickActionGrid.perRow(5), 3); // 3 + 2
    expect(QuickActionGrid.perRow(6), 3); // 3 + 3
    expect(QuickActionGrid.perRow(7), 4); // 4 + 3
    expect(QuickActionGrid.perRow(8), 4); // 4 + 4
    expect(QuickActionGrid.perRow(9), 3); // 3 + 3 + 3
  });

  testWidgets('five: same widths, last row centred, a row equally tall',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: QuickActionGrid(actions: _actions(5)),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    Rect tile(int i) => tester.getRect(find
        .ancestor(
          of: find.text(i == 3 ? 'نشاطات ترفيهية طويلة جدا' : 'إجراء $i'),
          matching: find.byType(Material),
        )
        .first);

    // Row one: 0, 1, 2. Row two: 3, 4.
    expect(tile(0).top, tile(2).top);
    expect(tile(3).top, greaterThan(tile(0).bottom));
    expect(tile(3).width, closeTo(tile(0).width, 0.01));

    // The short row sits in the middle of the card.
    final rowMid = (tile(3).left + tile(4).right) / 2;
    final topMid = (tile(0).left + tile(2).right) / 2;
    expect(rowMid, closeTo(topMid, 0.5));

    // The two-line tile and its neighbour are the same height.
    expect(tile(3).height, closeTo(tile(4).height, 0.01));
  });
}
