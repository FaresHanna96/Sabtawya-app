import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/core/widgets/pill_tabs.dart';
import 'package:sabtawya/core/widgets/soft_transitions.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/attendance/attendance_screen.dart';
import 'package:sabtawya/features/home/app_nav_bar.dart';
import 'package:sabtawya/features/home/more_entries.dart';
import 'package:sabtawya/features/home/quick_actions.dart';

Widget _app(Widget home, {bool still = false}) => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: child!,
        ),
      ),
      home: home,
    );

void main() {
  group('header', () {
    test('rounded below, with a shadow once content is under it', () {
      final bar = AppTheme.light().appBarTheme;
      expect(bar.shape, AppTheme.headerShape);
      expect(bar.scrolledUnderElevation, greaterThan(0));
    });

    testWidgets('the back button is the rounded chip, and goes back',
        (tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(appBar: AppBar()),
            ),
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackChip));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('tabs', () {
    test('white on the header, navy on a page', () {
      const tabs = [Tab(text: 'a'), Tab(text: 'b')];
      expect(pillTabs(tabs: tabs, onDark: true).labelColor, Colors.white);
      expect(pillTabs(tabs: tabs).labelColor, AppColors.navy);
    });

    test('long labels scroll when asked', () {
      final bar = pillTabs(tabs: const [Tab(text: 'a')], scrollable: true);
      expect(bar.isScrollable, isTrue);
      expect(bar.tabAlignment, TabAlignment.center);
    });
  });

  group('transitions', () {
    Future<Finder> push(WidgetTester tester, {required bool still}) async {
      await tester.pumpWidget(_app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const Text('next')),
            ),
            child: const Text('open'),
          ),
        ),
        still: still,
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      return find.text('next');
    }

    testWidgets('the page comes in from the left in Arabic', (tester) async {
      final next = await push(tester, still: false);
      final start = tester.getTopLeft(next).dx;
      await tester.pumpAndSettle();
      expect(start, lessThan(tester.getTopLeft(next).dx));
    });

    testWidgets('reduced motion: it is in place at once', (tester) async {
      final next = await push(tester, still: true);
      final start = tester.getTopLeft(next);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(next), start);
    });

    testWidgets('reducedMotion follows the phone', (tester) async {
      late bool value;
      await tester.pumpWidget(_app(
        Builder(builder: (context) {
          value = reducedMotion(context);
          return const SizedBox();
        }),
        still: true,
      ));
      expect(value, isTrue);
    });
  });

  group('quick actions', () {
    List<String> ids(HomeTab tab, MoreRole role) =>
        [for (final a in quickActionsFor(tab, role)) a.id];

    test('each tab offers its own, by role', () {
      expect(ids(HomeTab.home, MoreRole.servant), ['search', 'notifications']);
      expect(ids(HomeTab.classes, MoreRole.admin), ['search', 'committed']);
      expect(ids(HomeTab.children, MoreRole.servant),
          ['search', 'addChild', 'birthdays', 'missingInfo']);
      expect(ids(HomeTab.attendance, MoreRole.admin),
          ['attendanceHistory', 'absence']);
      expect(ids(HomeTab.activities, MoreRole.admin), ['preps']);
      expect(ids(HomeTab.more, MoreRole.generalServant), ['settings']);
    });

    test('nobody is offered what their role does not have', () {
      expect(ids(HomeTab.children, MoreRole.generalServant),
          isNot(contains('addChild')));
      expect(ids(HomeTab.activities, MoreRole.servant), isEmpty);
      for (final role in MoreRole.values) {
        final mine = {for (final e in MoreCatalog.entriesFor(role)) e.id};
        for (final tab in HomeTab.values) {
          for (final a in quickActionsFor(tab, role)) {
            if (a.open != null) expect(mine, contains(a.id));
          }
        }
      }
    });

    testWidgets('the sheet returns the chosen action', (tester) async {
      QuickAction? chosen;
      await tester.pumpWidget(_app(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen = await showQuickActions(
              context,
              title: 'المخدومين',
              actions: quickActionsFor(HomeTab.children, MoreRole.admin),
            ),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.addChild));
      await tester.pumpAndSettle();
      expect(chosen?.id, QuickAction.addChildId);
    });

    testWidgets('a long press on a tab asks for its shortcuts', (tester) async {
      int? pressed;
      await tester.pumpWidget(_app(Scaffold(
        bottomNavigationBar: AppNavBar(
          selectedIndex: 0,
          onSelected: (_) {},
          onLongPress: (i) => pressed = i,
          items: [
            for (final label in ['أ', 'ب'])
              AppNavItem(
                label: label,
                color: AppColors.olive,
                icon: const Icon(Icons.circle_outlined),
                selectedIcon: const Icon(Icons.circle),
              ),
          ],
        ),
      )));
      await tester.longPress(find.text('ب'));
      expect(pressed, 1);
    });
  });

  group('attendance', () {
    testWidgets('the ring shows the share present', (tester) async {
      await tester.pumpWidget(
          _app(const Center(child: AttendanceRing(present: 3, total: 4))));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .value,
        0.75,
      );
    });

    testWidgets('an empty list is an empty ring', (tester) async {
      await tester.pumpWidget(
          _app(const Center(child: AttendanceRing(present: 0, total: 0))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('each practice button is a full finger tall', (tester) async {
      final year = AttendanceYear(
        id: 'y',
        name: '2026 - 2027',
        startDate: DateTime(2026, 9, 26),
        endDate: DateTime(2027, 6, 26),
        sessionWeekday: 6,
        pointsSundaySchool: 5,
        pointsVespers: 5,
        pointsMass: 5,
        pointsConfession: 5,
        maxPointsPerSession: 20,
        isCurrent: true,
      );
      await tester.pumpWidget(_app(Scaffold(
        body: AttendanceEntryCard(
          entry: AttendanceEntry.from(
            child: const Child(
              id: 'a',
              classId: 'c',
              fullName: 'مخدوم',
              gender: Gender.boy,
              isActive: true,
            ),
            year: year,
            record: null,
          ),
          enabled: true,
          onToggle: (_) {},
        ),
      )));
      await tester.pumpAndSettle();
      // The pills are the animated boxes of the card.
      final pills = find.byWidgetPredicate((w) =>
          w is AnimatedContainer &&
          w.constraints?.minHeight == 44);
      expect(pills, findsAtLeastNWidgets(3));
      for (var i = 0; i < pills.evaluate().length; i++) {
        expect(tester.getSize(pills.at(i)).height, greaterThanOrEqualTo(44));
      }
    });
  });
}
