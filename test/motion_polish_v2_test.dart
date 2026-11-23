import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/widgets/motion.dart';
import 'package:sabtawya/data/models/school_class.dart';
import 'package:sabtawya/features/classes/classes_screen.dart';
import 'package:sabtawya/features/classes/patron_avatar.dart';
import 'package:sabtawya/features/home/home_shell.dart';

Widget _app(Widget child, {bool still = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );

double _scale(WidgetTester tester) => tester
    .widget<ScaleTransition>(find.descendant(
      of: find.byType(PopOnIncrease),
      matching: find.byType(ScaleTransition),
    ))
    .scale
    .value;

Widget _pop(int value) => PopOnIncrease(
      value: value,
      child: const SizedBox(width: 20, height: 20),
    );

void main() {
  group('PopOnIncrease', () {
    testWidgets('a rising count pops, then settles back', (tester) async {
      await tester.pumpWidget(_app(_pop(1)));
      expect(_scale(tester), 1.0);
      await tester.pumpWidget(_app(_pop(2)));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_scale(tester), greaterThan(1.05));
      await tester.pumpAndSettle();
      expect(_scale(tester), closeTo(1.0, 0.001));
    });

    testWidgets('a falling count does nothing', (tester) async {
      await tester.pumpWidget(_app(_pop(3)));
      await tester.pumpWidget(_app(_pop(1)));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_scale(tester), 1.0);
    });

    testWidgets('reduce motion: no pop', (tester) async {
      await tester.pumpWidget(_app(_pop(1), still: true));
      await tester.pumpWidget(_app(_pop(5), still: true));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_scale(tester), 1.0);
    });
  });

  group('syncJustFinished', () {
    test('the queue emptied online with nothing refused', () {
      expect(syncJustFinished(before: 3, after: 0, failed: 0, online: true),
          isTrue);
    });
    test('still sending', () {
      expect(syncJustFinished(before: 3, after: 1, failed: 0, online: true),
          isFalse);
    });
    test('nothing was waiting', () {
      expect(syncJustFinished(before: 0, after: 0, failed: 0, online: true),
          isFalse);
    });
    test('some were refused: the warning banner stays instead', () {
      expect(syncJustFinished(before: 3, after: 0, failed: 1, online: true),
          isFalse);
    });
    test('offline', () {
      expect(syncJustFinished(before: 3, after: 0, failed: 0, online: false),
          isFalse);
    });
  });

  testWidgets('the synced banner says so', (tester) async {
    await tester.pumpWidget(_app(const SyncedBanner()));
    expect(find.text(AppStrings.syncedAll), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
  });

  testWidgets('a class card gives its patron picture the shared hero tag',
      (tester) async {
    await tester.pumpWidget(_app(SizedBox(
      width: 360,
      child: ClassCard(
        overview: const ClassOverview(
          classId: 'c7',
          className: '6 بنات',
          sortOrder: 1,
          isActive: true,
          activeChildren: 10,
          boysCount: 0,
          girlsCount: 10,
          servantsCount: 1,
        ),
        accent: Colors.blue,
        saturday: DateTime(2026, 11, 21),
        facts: const ClassCardFacts(),
        onRecord: () {},
        onTap: () {},
      ),
    )));
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, patronHeroTag('c7'));
    expect(
        find.descendant(
            of: find.byType(Hero), matching: find.byType(PatronAvatar)),
        findsOneWidget);
  });
}
