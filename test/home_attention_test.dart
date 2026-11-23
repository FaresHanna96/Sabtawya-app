import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/features/dashboard/home_numbers_card.dart';
import 'package:sabtawya/features/dashboard/needs_attention_card.dart';
import 'package:sabtawya/features/home/more_entries.dart';

Future<void> _pump(WidgetTester tester, Widget child, {double width = 360}) =>
    tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Center(child: SizedBox(width: width, child: child)),
          ),
        ),
      ),
    ));

const _all = {
  MoreCount.absence: 77,
  MoreCount.missingInfo: 80,
  MoreCount.pendingPreps: 3,
  MoreCount.invites: 1,
  MoreCount.birthdays: 2,
};

void main() {
  group('attentionItems', () {
    test('the admin sees all four, in order, with their counts', () {
      final items = attentionItems(_all, isAdmin: true);
      expect(items.map((i) => i.entry.id),
          ['absence', 'missingInfo', 'preps', 'servants']);
      expect(items.map((i) => i.count), [77, 80, 3, 1]);
    });

    test('a general servant gets no preps or join requests', () {
      final items = attentionItems(_all, isAdmin: false);
      expect(items.map((i) => i.entry.id), ['absence', 'missingInfo']);
    });

    test('zero and missing counts are left out', () {
      final items = attentionItems(
        {MoreCount.absence: 0, MoreCount.pendingPreps: 2},
        isAdmin: true,
      );
      expect(items.map((i) => i.entry.id), ['preps']);
    });

    test('birthdays are not an attention line', () {
      final items = attentionItems({MoreCount.birthdays: 4}, isAdmin: true);
      expect(items, isEmpty);
    });
  });

  group('NeedsAttentionCard', () {
    testWidgets('lists what waits and opens it on tap', (tester) async {
      Widget? opened;
      await _pump(
        tester,
        NeedsAttentionCard(
          isAdmin: true,
          yearId: 'y',
          load: () async => const {
            MoreCount.absence: 5,
            MoreCount.pendingPreps: 2,
          },
          onOpen: (screen) async => opened = screen,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.needsAttention), findsOneWidget);
      expect(find.text(AppStrings.absenceFollowUp), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text(AppStrings.prepsInboxTitle), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text(AppStrings.missingInfoTitle), findsNothing);

      final preps =
          MoreCatalog.all.firstWhere((e) => e.id == 'preps').open!();
      await tester.tap(find.text(AppStrings.prepsInboxTitle));
      await tester.pump();
      expect(opened.runtimeType, preps.runtimeType);
    });

    testWidgets('nothing waiting: no card at all', (tester) async {
      await _pump(
        tester,
        NeedsAttentionCard(
          isAdmin: true,
          yearId: 'y',
          load: () async => const {},
          onOpen: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.needsAttention), findsNothing);
    });

    testWidgets('a failed load shows no card', (tester) async {
      await _pump(
        tester,
        NeedsAttentionCard(
          isAdmin: true,
          yearId: 'y',
          load: () async => throw Exception('offline'),
          onOpen: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.needsAttention), findsNothing);
    });
  });

  group('HomeNumbersCard', () {
    testWidgets('shows the four numbers and the boys/girls split',
        (tester) async {
      await _pump(
        tester,
        const HomeNumbersCard(
          children: 80,
          classes: 8,
          servants: 12,
          admins: 2,
          boys: 41,
          girls: 39,
        ),
      );
      await tester.pumpAndSettle();
      for (final n in ['80', '8', '12', '2']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text(AppStrings.totalChildren), findsOneWidget);
      expect(find.textContaining('41'), findsOneWidget);
      expect(find.textContaining('39'), findsOneWidget);
    });

    testWidgets('fits a narrow phone without overflow', (tester) async {
      await _pump(
        tester,
        const HomeNumbersCard(
          children: 1200,
          classes: 16,
          servants: 140,
          admins: 12,
          boys: 600,
          girls: 600,
        ),
        width: 288,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('no children yet: no split bar', (tester) async {
      await _pump(
        tester,
        const HomeNumbersCard(
          children: 0,
          classes: 0,
          servants: 0,
          admins: 1,
          boys: 0,
          girls: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.boy_rounded), findsNothing);
    });
  });
}
