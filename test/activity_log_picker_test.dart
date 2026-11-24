import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/activity_log/activity_log_screen.dart';

Child _child(String id, String name) => Child(
      id: id,
      classId: 'c',
      fullName: name,
      gender: Gender.boy,
      isActive: true,
    );

final _children = [
  _child('1', 'مينا عادل'),
  _child('2', 'بولا نبيل'),
  _child('3', 'أنطونيوس سامي'),
];

/// Opens the picker the way the screen does and returns what it answers.
Future<Child?> _open(WidgetTester tester, Future<void> Function() act) async {
  Child? picked;
  var done = false;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            picked = await showModalBottomSheet<Child>(
              context: context,
              isScrollControlled: true,
              builder: (_) => ChildPickerSheet(children: _children),
            );
            done = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await act();
  await tester.pumpAndSettle();
  expect(done, isTrue);
  return picked;
}

void main() {
  testWidgets('lists every child, sorted by name', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ChildPickerSheet(children: _children)),
    ));

    final names = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title as Text).data)
        .toList();
    expect(names, hasLength(3));
    expect(names.toSet(), {'مينا عادل', 'بولا نبيل', 'أنطونيوس سامي'});
  });

  testWidgets('typing narrows the list', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ChildPickerSheet(children: _children)),
    ));

    await tester.enterText(find.byType(TextField), 'بولا');
    await tester.pump();

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('بولا نبيل'), findsOneWidget);
  });

  testWidgets('a name that matches nobody says so', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ChildPickerSheet(children: _children)),
    ));

    await tester.enterText(find.byType(TextField), 'ززززز');
    await tester.pump();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('مفيش نتايج'), findsOneWidget);
  });

  testWidgets('tapping a child closes the sheet with that child',
      (tester) async {
    final picked = await _open(tester, () async {
      await tester.tap(find.text('بولا نبيل'));
    });

    expect(picked?.id, '2');
  });

  testWidgets('dismissing it answers nothing', (tester) async {
    final picked = await _open(tester, () async {
      await tester.tapAt(const Offset(10, 10)); // the barrier
    });

    expect(picked, isNull);
  });
}
