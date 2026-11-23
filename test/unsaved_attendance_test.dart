import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/features/attendance/attendance_screen.dart';
import 'package:sabtawya/features/home/home_shell.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    );

Badge _badge(WidgetTester tester) => tester.widget<Badge>(find.byType(Badge));

void main() {
  group('AttendanceTabIcon', () {
    testWidgets('no badge when saved and nothing pending', (tester) async {
      await tester.pumpWidget(_wrap(const AttendanceTabIcon(
        icon: Icons.fact_check_outlined,
        pendingCount: 0,
        unsaved: false,
      )));
      expect(_badge(tester).isLabelVisible, isFalse);
    });

    testWidgets('a dot while marks are not saved', (tester) async {
      await tester.pumpWidget(_wrap(const AttendanceTabIcon(
        icon: Icons.fact_check_outlined,
        pendingCount: 0,
        unsaved: true,
      )));
      final badge = _badge(tester);
      expect(badge.isLabelVisible, isTrue);
      expect(badge.label, isNull, reason: 'a dot, not a number');
    });

    testWidgets('the pending-sync count wins over the dot', (tester) async {
      await tester.pumpWidget(_wrap(const AttendanceTabIcon(
        icon: Icons.fact_check_outlined,
        pendingCount: 3,
        unsaved: true,
      )));
      await tester.pumpAndSettle();
      expect(_badge(tester).label, isNotNull);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('follows AttendanceScreen.unsavedInTab', (tester) async {
      addTearDown(() => AttendanceScreen.unsavedInTab.value = false);
      await tester.pumpWidget(_wrap(ValueListenableBuilder<bool>(
        valueListenable: AttendanceScreen.unsavedInTab,
        builder: (_, unsaved, __) => AttendanceTabIcon(
          icon: Icons.fact_check_outlined,
          pendingCount: 0,
          unsaved: unsaved,
        ),
      )));
      expect(_badge(tester).isLabelVisible, isFalse);
      AttendanceScreen.unsavedInTab.value = true;
      await tester.pump();
      expect(_badge(tester).isLabelVisible, isTrue);
      AttendanceScreen.unsavedInTab.value = false;
      await tester.pump();
      expect(_badge(tester).isLabelVisible, isFalse);
    });
  });

  group('unsavedAttendanceSnackBar', () {
    test('goes away by itself even though it has an action', () {
      final bar = unsavedAttendanceSnackBar(onBack: () {});
      expect(bar.persist, isFalse);
      expect(bar.action?.label, AppStrings.backToAttendance);
    });

    testWidgets('disappears after its duration and its action runs onBack',
        (tester) async {
      var back = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                unsavedAttendanceSnackBar(onBack: () => back++),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.attendanceNotSaved), findsOneWidget);
      await tester.tap(find.text(AppStrings.backToAttendance));
      await tester.pumpAndSettle();
      expect(back, 1);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.attendanceNotSaved), findsNothing,
          reason: 'it must not stay on screen until tapped');
    });
  });
}
