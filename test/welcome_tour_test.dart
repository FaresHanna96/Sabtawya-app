import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/features/home/more_entries.dart';
import 'package:sabtawya/features/home/welcome_tour.dart';

Widget _rtl(Widget child) => MaterialApp(
      // Reduce motion: the floating icon then stays still, so the tests can
      // wait for the screen to settle (and it covers people who use it).
      builder: _stillMotion,
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

Widget _stillMotion(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    );

void main() {
  group('tourPagesFor', () {
    for (final role in MoreRole.values) {
      test('$role: four pages, the welcome first', () {
        final pages = tourPagesFor(role);
        expect(pages, hasLength(4));
        expect(pages.first.title, AppStrings.tourWelcomeTitle);
      });
    }

    test('only a class servant is told about uploading a prep', () {
      expect(tourPagesFor(MoreRole.servant).map((p) => p.title),
          contains(AppStrings.tourPrepTitle));
      expect(tourPagesFor(MoreRole.admin).map((p) => p.title),
          isNot(contains(AppStrings.tourPrepTitle)));
      expect(tourPagesFor(MoreRole.generalServant).map((p) => p.title),
          isNot(contains(AppStrings.tourPrepTitle)));
    });

    test('the admin hears about class health and the review queue', () {
      final pages = tourPagesFor(MoreRole.admin);
      expect(pages.map((p) => p.title), contains(AppStrings.tourClassesTitle));
      expect(
          pages.map((p) => p.body), contains(AppStrings.tourFollowUpAdminBody));
    });
  });

  group('WelcomeTour.maybeShow', () {
    Future<List<bool>> pumpOpener(WidgetTester tester, TourStore store) async {
      final results = <bool>[];
      await tester.pumpWidget(_rtl(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await WelcomeTour.maybeShow(
                context,
                store: store,
                role: MoreRole.servant,
              ),
            ),
            child: const Text('go'),
          ),
        ),
      )));
      return results;
    }

    testWidgets('shows once on this phone, then never again', (tester) async {
      final store = TourStore.memory();
      final results = await pumpOpener(tester, store);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeTourScreen), findsOneWidget);
      expect(await store.seen(), kTourVersion);
      await tester.tap(find.text(AppStrings.tourSkip));
      await tester.pumpAndSettle();
      expect(results, [true]);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeTourScreen), findsNothing);
      expect(results, [true, false]);
    });

    testWidgets('a home gone before the check does not use up the tour',
        (tester) async {
      final gate = Completer<void>();
      final store = TourStore.memory(0, gate.future);
      late BuildContext homeContext;
      await tester.pumpWidget(_rtl(Builder(builder: (context) {
        homeContext = context;
        return const SizedBox.shrink();
      })));
      final shown = WelcomeTour.maybeShow(homeContext,
          store: store, role: MoreRole.servant);
      // The home is rebuilt (the first copy goes) before the check answers.
      await tester.pumpWidget(_rtl(const SizedBox.shrink()));
      gate.complete();
      expect(await shown, isFalse);
      expect(await store.seen(), 0, reason: 'still to show');
    });

    testWidgets('a phone that saw this version gets nothing', (tester) async {
      final results = await pumpOpener(tester, TourStore.memory(kTourVersion));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(results, [false]);
      expect(find.byType(WelcomeTourScreen), findsNothing);
    });
  });

  group('WelcomeTourScreen', () {
    testWidgets('«التالي» through the pages, then «يلا نبدأ» closes it',
        (tester) async {
      await tester.pumpWidget(_rtl(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const WelcomeTourScreen(role: MoreRole.servant),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final pages = tourPagesFor(MoreRole.servant);
      for (var i = 0; i < pages.length - 1; i++) {
        expect(find.text(pages[i].title), findsOneWidget);
        await tester.tap(find.text(AppStrings.tourNext));
        await tester.pumpAndSettle();
      }
      expect(find.text(pages.last.title), findsOneWidget);
      expect(find.text(AppStrings.tourStart), findsOneWidget);
      await tester.tap(find.text(AppStrings.tourStart));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeTourScreen), findsNothing);
    });

    testWidgets('«تخطي» leaves at once', (tester) async {
      await tester.pumpWidget(_rtl(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const WelcomeTourScreen(role: MoreRole.admin),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.tourSkip));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeTourScreen), findsNothing);
    });

    for (final role in MoreRole.values) {
      testWidgets('$role: every page fits a small phone at large text',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.5),
              disableAnimations: true,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: WelcomeTourScreen(role: role),
            ),
          ),
        ));
        for (var i = 0; i < tourPagesFor(role).length; i++) {
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'page ${i + 1}');
          if (i < tourPagesFor(role).length - 1) {
            await tester.tap(find.text(AppStrings.tourNext));
          }
        }
      });
    }
  });

  test('المزيد offers the tour again', () {
    final entry = MoreCatalog.all.firstWhere((e) => e.id == 'tour');
    expect(entry.title, AppStrings.tourMenu);
    expect(entry.open!(), isA<WelcomeTourScreen>());
  });
}
