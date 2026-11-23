import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/data/models/servant_activity.dart';
import 'package:sabtawya/features/servant_activities/servant_day_widgets.dart';

LessonPrep _prep(String servantId, String status) => LessonPrep.fromMap({
      'id': 'p-$servantId',
      'servant_id': servantId,
      'session_id': 's',
      'status': status,
      'attendance_sessions': {'session_date': '2026-11-21'},
    });

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 800),
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(padding: const EdgeInsets.all(12), child: child),
          ),
        ),
      ),
    );

ServantSlot _slot(String label, {bool on = false, VoidCallback? onTap}) =>
    ServantSlot(
      label: label,
      icon: Icons.circle_outlined,
      color: AppColors.success,
      on: on,
      onTap: onTap ?? () {},
    );

void main() {
  group('ServantDayProgress', () {
    test('a servant with any of the four marks counts as marked', () {
      final marks = {
        'a': {'mass'},
        'b': <String>{},
        'c': {'sunday_school', 'confession'},
      };
      final p = ServantDayProgress.of(
        servantIds: ['a', 'b', 'c'],
        isMarked: (id, type) => marks[id]!.contains(type),
        preps: [_prep('a', 'pending'), _prep('c', 'accepted')],
      );
      expect(p.marked, 2);
      expect(p.total, 3);
      expect(p.pendingPreps, 1);
      expect(p.share, closeTo(2 / 3, 0.001));
    });

    test('a manual prep alone is not attendance', () {
      final p = ServantDayProgress.of(
        servantIds: ['a'],
        isMarked: (id, type) => type == 'lesson_prep',
        preps: const [],
      );
      expect(p.marked, 0);
    });

    test('nobody to mark: no division by zero', () {
      final p = ServantDayProgress.of(
          servantIds: const [], isMarked: (_, __) => false, preps: const []);
      expect(p.share, 0);
    });
  });

  testWidgets('the progress line says how far the Saturday got',
      (tester) async {
    await tester.pumpWidget(_app(const ServantDayProgressLine(
      progress: ServantDayProgress(marked: 12, total: 18, pendingPreps: 3),
    )));
    expect(find.text(AppStrings.servantsMarkedOf(12, 18)), findsOneWidget);
    expect(find.text(AppStrings.prepsWaitingReview(3)), findsOneWidget);
  });

  group('ServantDayRow', () {
    Widget row({VoidCallback? onOpen, VoidCallback? onMass}) => ServantDayRow(
          name: 'أمين خدمة تجريبي طويل الاسم جدا',
          className: '6 بنات',
          onOpen: onOpen ?? () {},
          slots: [
            _slot(AppStrings.chipPrep),
            _slot(AppStrings.chipService, on: true),
            _slot(AppStrings.chipMeeting),
            _slot(AppStrings.massShort, onTap: onMass),
            _slot(AppStrings.confessionShort),
          ],
        );

    testWidgets('five slots in one row, the class under the name',
        (tester) async {
      await tester.pumpWidget(_app(row()));
      expect(find.byType(ServantSlot), findsNWidgets(5));
      final ys = {
        for (final e in find.byType(ServantSlot).evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dy,
      };
      expect(ys, hasLength(1), reason: 'all on the same line');
      expect(find.textContaining('6 بنات'), findsOneWidget);
    });

    testWidgets('a general servant says so', (tester) async {
      await tester.pumpWidget(_app(ServantDayRow(
        name: 'خادم عام',
        className: null,
        onOpen: () {},
        slots: [_slot(AppStrings.chipPrep)],
      )));
      expect(
          find.textContaining(AppStrings.generalServantShort), findsOneWidget);
    });

    testWidgets('taps: a slot toggles, the name opens the servant',
        (tester) async {
      var mass = 0;
      var opened = 0;
      await tester
          .pumpWidget(_app(row(onMass: () => mass++, onOpen: () => opened++)));
      await tester.tap(find.text(AppStrings.massShort));
      await tester.tap(find.textContaining('6 بنات'));
      expect(mass, 1);
      expect(opened, 1);
    });

    testWidgets('fits a small phone at large text', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(row(), scale: 1.5));
      expect(tester.takeException(), isNull);
    });
  });
}
