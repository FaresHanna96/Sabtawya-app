import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/features/dashboard/needs_attention_strip.dart';
import 'package:sabtawya/features/home/more_entries.dart';

Future<void> _pump(
  WidgetTester tester,
  Map<MoreCount, int> counts, {
  void Function(String)? onOpen,
  double width = 300,
}) =>
    tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: NeedsAttentionStrip(
                  counts: counts, onOpen: onOpen ?? (_) {}),
            ),
          ),
        ),
      ),
    ));

void main() {
  testWidgets('shows only the numbers above zero', (tester) async {
    await _pump(tester, {
      MoreCount.absence: 77,
      MoreCount.missingInfo: 0,
      MoreCount.pendingPreps: 3,
    });
    expect(find.text('${AppStrings.attnAbsence} · 77'), findsOneWidget);
    expect(find.text('${AppStrings.attnPreps} · 3'), findsOneWidget);
    expect(find.textContaining(AppStrings.attnMissing), findsNothing);
    expect(find.textContaining(AppStrings.attnInvites), findsNothing);
    expect(find.text(AppStrings.needsAttention), findsOneWidget);
  });

  testWidgets('nothing to act on: nothing is drawn', (tester) async {
    await _pump(tester, {MoreCount.absence: 0});
    expect(find.text(AppStrings.needsAttention), findsNothing);
  });

  testWidgets('a tap opens that entry', (tester) async {
    String? opened;
    await _pump(tester, {MoreCount.missingInfo: 5}, onOpen: (id) => opened = id);
    await tester.tap(find.text('${AppStrings.attnMissing} · 5'));
    expect(opened, 'missingInfo');
  });

  test('every item points to a real المزيد entry', () {
    final ids = MoreCatalog.all.map((e) => e.id).toSet();
    for (final i in attentionItems) {
      expect(ids, contains(i.entryId));
    }
  });

  testWidgets('fits a narrow phone with all four', (tester) async {
    await _pump(
      tester,
      {
        MoreCount.absence: 77,
        MoreCount.missingInfo: 80,
        MoreCount.pendingPreps: 3,
        MoreCount.invites: 1,
      },
      width: 288,
    );
    expect(tester.takeException(), isNull);
  });
}
