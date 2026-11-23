import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/features/dashboard/home_numbers_card.dart';

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

void main() {
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
