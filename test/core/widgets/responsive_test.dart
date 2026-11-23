import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/app.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/core/widgets/responsive.dart';

void _setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('isWideLayout', () {
    for (final (width, wide) in [
      (375.0, false),
      (899.0, false),
      (900.0, true)
    ]) {
      testWidgets('$width px is ${wide ? 'wide' : 'narrow'}', (tester) async {
        _setSurface(tester, Size(width, 800));
        late bool seen;
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
            seen = isWideLayout(context);
            return const SizedBox.shrink();
          }),
        ));
        expect(seen, wide);
      });
    }
  });

  group('MaxWidthBox', () {
    testWidgets('caps and tells the child its column width', (tester) async {
      _setSurface(tester, const Size(1400, 800));
      late double seen;
      await tester.pumpWidget(MaterialApp(
        home: MaxWidthBox(
          maxWidth: 720,
          child: Builder(builder: (context) {
            seen = MediaQuery.sizeOf(context).width;
            return const SizedBox.expand(key: Key('c'));
          }),
        ),
      ));
      expect(tester.getSize(find.byKey(const Key('c'))).width, 720);
      expect(seen, 720);
    });

    testWidgets('a narrower space wins over the cap', (tester) async {
      _setSurface(tester, const Size(1000, 800));
      late double seen;
      await tester.pumpWidget(MaterialApp(
        home: Row(children: [
          const SizedBox(width: 100),
          Expanded(
            child: MaxWidthBox(
              maxWidth: 960,
              child: Builder(builder: (context) {
                seen = MediaQuery.sizeOf(context).width;
                return const SizedBox.expand(key: Key('c'));
              }),
            ),
          ),
        ]),
      ));
      expect(tester.getSize(find.byKey(const Key('c'))).width, 900);
      expect(seen, 900, reason: 'the space it has, not the window');
    });

    testWidgets('a phone is left alone', (tester) async {
      _setSurface(tester, const Size(375, 800));
      await tester.pumpWidget(const MaterialApp(
        home: MaxWidthBox(maxWidth: 720, child: SizedBox.expand(key: Key('c'))),
      ));
      expect(tester.getSize(find.byKey(const Key('c'))).width, 375);
      expect(find.byType(Center), findsNothing);
    });
  });

  group('TwoColumns', () {
    Future<void> pumpAt(WidgetTester tester, double width) {
      _setSurface(tester, Size(width, 1200));
      return tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: TwoColumns(
              main: const [SizedBox(height: 50, key: Key('a'))],
              side: const [SizedBox(height: 50, key: Key('b'))],
            ),
          ),
        ),
      ));
    }

    testWidgets('narrow: main above side', (tester) async {
      await pumpAt(tester, 400);
      final a = tester.getTopLeft(find.byKey(const Key('a')));
      final b = tester.getTopLeft(find.byKey(const Key('b')));
      expect(b.dy, greaterThan(a.dy));
    });

    testWidgets('wide: side by side, main at the start (right in Arabic)',
        (tester) async {
      await pumpAt(tester, 1100);
      final a = tester.getTopLeft(find.byKey(const Key('a')));
      final b = tester.getTopLeft(find.byKey(const Key('b')));
      expect(a.dy, b.dy);
      expect(a.dx, greaterThan(b.dx));
    });
  });

  group('opened screens', () {
    Future<double> pushedWidth(WidgetTester tester, double window) async {
      _setSurface(tester, Size(window, 800));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        builder: appFrame,
        home: Builder(
          builder: (context) => Scaffold(
            key: const Key('home'),
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(key: Key('page')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return tester.getSize(find.byKey(const Key('page'))).width;
    }

    testWidgets('keep a readable width on a desktop', (tester) async {
      expect(await pushedWidth(tester, 1400), kPageMaxWidth);
    });

    testWidgets('use the whole phone', (tester) async {
      expect(await pushedWidth(tester, 375), 375);
    });

    testWidgets('the home itself uses the window', (tester) async {
      _setSurface(tester, const Size(1300, 800));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        builder: appFrame,
        home: const Scaffold(key: Key('home')),
      ));
      expect(tester.getSize(find.byKey(const Key('home'))).width, 1300);
    });
  });
}
