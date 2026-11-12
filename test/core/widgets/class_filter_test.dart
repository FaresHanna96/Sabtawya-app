import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/widgets/class_filter_chips.dart';

const _classes = [
  ClassFilterOption(id: 'b3', name: '3 ولاد'),
  ClassFilterOption(id: 'g3', name: '3 بنات'),
  ClassFilterOption(id: 'b4', name: '4 ولاد'),
  ClassFilterOption(id: 'g4', name: '4 بنات'),
];

Widget _host(String? selected, ValueChanged<String?> onSelected,
        {bool showAll = true}) =>
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ClassFilterChips(
              classes: _classes,
              selectedId: selected,
              showAll: showAll,
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('shows one compact button, not the grid', (tester) async {
    await tester.pumpWidget(_host(null, (_) {}));
    expect(find.text(AppStrings.allClasses), findsOneWidget);
    expect(find.byType(ClassFilterGrid), findsNothing);
    expect(tester.getSize(find.byType(ClassFilterChips)).height, 42);
  });

  testWidgets('tapping opens the grid; picking a class closes it',
      (tester) async {
    String? picked = 'none';
    await tester.pumpWidget(_host(null, (id) => picked = id));

    await tester.tap(find.byType(ClassFilterChips));
    await tester.pumpAndSettle();
    expect(find.byType(ClassFilterGrid), findsOneWidget);

    await tester.tap(find.text('4 بنات'));
    await tester.pumpAndSettle();
    expect(picked, 'g4');
    expect(find.byType(ClassFilterGrid), findsNothing);
  });

  testWidgets('a chosen class shows its name and a clear button',
      (tester) async {
    String? picked = 'none';
    await tester.pumpWidget(_host('b3', (id) => picked = id));
    expect(find.text('3 ولاد'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    expect(picked, isNull);
  });

  testWidgets('without "all", no clear button and the right prompt',
      (tester) async {
    await tester.pumpWidget(_host(null, (_) {}, showAll: false));
    expect(find.text(AppStrings.selectClass), findsOneWidget);

    await tester.pumpWidget(_host('g3', (_) {}, showAll: false));
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
