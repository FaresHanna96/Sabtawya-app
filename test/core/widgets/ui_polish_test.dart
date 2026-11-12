import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/app.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/core/widgets/async_section.dart';
import 'package:sabtawya/core/widgets/skeleton.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/attendance/attendance_screen.dart';

Widget _rtl(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

void _setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

AttendanceEntry _entry({bool marked = false}) => AttendanceEntry(
      child: const Child(
        id: 'c1',
        classId: 'k1',
        fullName: 'مينا عادل تجريبي',
        gender: Gender.boy,
        isActive: true,
      ),
      sundaySchool: marked,
      vespers: marked,
      mass: marked,
      confession: marked,
      pointsSundaySchool: 5,
      pointsVespers: 5,
      pointsMass: 5,
      pointsConfession: 5,
      isRecorded: marked,
    );

void main() {
  group('AppIcons', () {
    test('are the chevrons Flutter mirrors in a right-to-left layout', () {
      // Mirrored, "chevron_right" is drawn pointing left: the direction a row
      // opens in Arabic. Picking chevron_left by hand pointed the wrong way.
      expect(AppIcons.forward, Icons.chevron_right);
      expect(AppIcons.back, Icons.chevron_left);
      expect(AppIcons.forward.matchTextDirection, isTrue);
      expect(AppIcons.back.matchTextDirection, isTrue);
    });
  });

  group('appFrame', () {
    Future<double> widthAt(WidgetTester tester, double window) async {
      _setSurface(tester, Size(window, 800));
      const key = Key('content');
      await tester.pumpWidget(
        MaterialApp(
          builder: appFrame,
          home: const SizedBox.expand(key: key),
        ),
      );
      return tester.getSize(find.byKey(key)).width;
    }

    testWidgets('caps the app on a wide window', (tester) async {
      expect(await widthAt(tester, 1200), kMaxAppWidth);
    });

    testWidgets('leaves a phone at full width', (tester) async {
      expect(await widthAt(tester, 375), 375);
    });

    testWidgets('screens measure the column, not the window', (tester) async {
      _setSurface(tester, const Size(1200, 800));
      late double seen;
      await tester.pumpWidget(
        MaterialApp(
          builder: appFrame,
          home: Builder(
            builder: (context) {
              seen = MediaQuery.of(context).size.width;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, kMaxAppWidth);
    });
  });

  group('AsyncSection', () {
    testWidgets('shows the skeleton while loading, then the content',
        (tester) async {
      final gate = Completer<String>();
      await tester.pumpWidget(
        _rtl(
          AsyncSection<String>(
            load: () => gate.future,
            loading: const SkeletonList(count: 3),
            builder: (_, data, __) => ListView(children: [Text(data)]),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);

      gate.complete('تم');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('تم'), findsOneWidget);
    });

    testWidgets('the skeleton stays still under reduce-motion', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _rtl(const SkeletonList(count: 2)),
        ),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('Attendance entry card', () {
    for (final marked in [false, true]) {
      testWidgets(
          'shows all four labels in full on a 375px phone '
          '(${marked ? 'marked' : 'unmarked'})', (tester) async {
        _setSurface(tester, const Size(375, 812));
        await tester.pumpWidget(
          _rtl(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AttendanceEntryCard(
                entry: _entry(marked: marked),
                enabled: true,
                onToggle: (_) {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // No RenderFlex overflow, and no label is cut with an ellipsis.
        expect(tester.takeException(), isNull);
        for (final label in [
          AppStrings.sundaySchoolShort,
          AppStrings.vespersShort,
          AppStrings.massShort,
          AppStrings.confessionShort,
        ]) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.overflow, isNull);
          expect(text.maxLines, 1);
        }
      });
    }

    testWidgets('a tap reports which activity was toggled', (tester) async {
      _setSurface(tester, const Size(375, 812));
      final tapped = <AttendanceActivity>[];
      await tester.pumpWidget(
        _rtl(
          AttendanceEntryCard(
            entry: _entry(),
            enabled: true,
            onToggle: tapped.add,
          ),
        ),
      );
      await tester.tap(find.text(AppStrings.massShort));
      expect(tapped, [AttendanceActivity.mass]);
    });
  });
}
