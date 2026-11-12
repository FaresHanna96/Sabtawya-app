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

Widget _host(Set<String> selected, ValueChanged<Set<String>> onChanged) =>
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ClassFilterChips(
              classes: _classes,
              selectedIds: selected,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );

void main() {
  group('labelFor', () {
    test('none or every class reads as all classes', () {
      expect(ClassFilterChips.labelFor(_classes, {}), AppStrings.allClasses);
      expect(
        ClassFilterChips.labelFor(_classes, {'b3', 'g3', 'b4', 'g4'}),
        AppStrings.allClasses,
      );
    });

    test('one or two classes are named, more are counted', () {
      expect(ClassFilterChips.labelFor(_classes, {'g4'}), '4 بنات');
      expect(ClassFilterChips.labelFor(_classes, {'g3', 'g4'}),
          '3 بنات، 4 بنات');
      expect(ClassFilterChips.labelFor(_classes, {'b3', 'g3', 'g4'}),
          AppStrings.classesCount(3));
    });
  });

  testWidgets('shows one compact button, not the grid', (tester) async {
    await tester.pumpWidget(_host({}, (_) {}));
    expect(find.text(AppStrings.allClasses), findsOneWidget);
    expect(find.byType(ClassFilterGrid), findsNothing);
    expect(tester.getSize(find.byType(ClassFilterChips)).height, 42);
  });

  testWidgets('several classes can be ticked, then applied with تم',
      (tester) async {
    Set<String>? picked;
    await tester.pumpWidget(_host({}, (ids) => picked = ids));

    await tester.tap(find.byType(ClassFilterChips));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 بنات'));
    await tester.tap(find.text('4 بنات'));
    await tester.pump();
    expect(picked, isNull, reason: 'nothing applies before تم');

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(picked, {'g3', 'g4'});
    expect(find.byType(ClassFilterGrid), findsNothing);
  });

  testWidgets('"الكل" in the sheet clears the ticks', (tester) async {
    Set<String>? picked;
    await tester.pumpWidget(_host({'b3'}, (ids) => picked = ids));

    await tester.tap(find.byType(ClassFilterChips));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.all));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
  });

  testWidgets('a chosen class shows its name and a clear button',
      (tester) async {
    Set<String>? picked;
    await tester.pumpWidget(_host({'b3'}, (ids) => picked = ids));
    expect(find.text('3 ولاد'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    expect(picked, isEmpty);
  });
}
