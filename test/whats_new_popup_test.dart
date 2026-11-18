import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/config/whats_new.dart';
import 'package:sabtawya/features/home/whats_new_popup.dart';

const _notes = {
  7: [WhatsNewItem(Icons.star, 'ميزة جديدة', 'شرح الميزة')],
};

Future<void> _open(WidgetTester t, WhatsNewStore store, int build) async {
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (c) => TextButton(
        onPressed: () => WhatsNewPopup.maybeShow(c, build: build, notes: _notes, store: store),
        child: const Text('go'),
      ),
    ),
  ));
  await t.tap(find.text('go'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('shows once after an update, then never again', (t) async {
    final store = WhatsNewStore.memory(6);
    await _open(t, store, 7);
    expect(find.text('ميزة جديدة'), findsOneWidget);
    await t.tap(find.text('تمام'));
    await t.pumpAndSettle();
    expect(await store.seen(), 7);
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.text('ميزة جديدة'), findsNothing);
  });

  testWidgets('a phone that never saw one gets this build\'s notes', (t) async {
    await _open(t, WhatsNewStore.memory(), 7);
    expect(find.text('جديد في سبتاوية'), findsOneWidget);
  });

  testWidgets('a build with no notes shows nothing but is remembered', (t) async {
    final store = WhatsNewStore.memory(6);
    await _open(t, store, 8);
    expect(find.text('جديد في سبتاوية'), findsNothing);
    expect(await store.seen(), 8);
  });

  testWidgets('already seen build is not shown again', (t) async {
    await _open(t, WhatsNewStore.memory(7), 7);
    expect(find.text('جديد في سبتاوية'), findsNothing);
  });
}
