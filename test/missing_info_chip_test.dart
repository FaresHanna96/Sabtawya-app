import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/features/children/missing_info_screen.dart';

Widget _app(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('a filter with something missing shows its count',
      (tester) async {
    await tester.pumpWidget(_app(FieldChip(
      label: 'رقم تليفون',
      count: 80,
      isSelected: false,
      onTap: () {},
      icon: Icons.phone_rounded,
    )));
    expect(find.text('رقم تليفون'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('a filter with nothing missing shows a tick, not zero',
      (tester) async {
    await tester.pumpWidget(_app(FieldChip(
      label: 'العنوان',
      count: 0,
      isSelected: false,
      onTap: () {},
    )));
    expect(find.text('0'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('tapping selects it', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(FieldChip(
      label: 'العنوان',
      count: 3,
      isSelected: false,
      onTap: () => taps++,
    )));
    await tester.tap(find.text('العنوان'));
    expect(taps, 1);
  });

  testWidgets('all seven fit a row that scrolls on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < 7; i++)
          FieldChip(
              label: 'اسم الأب $i', count: i, isSelected: i == 2, onTap: () {}),
      ]),
    )));
    expect(tester.takeException(), isNull);
  });
}
