import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/features/attendance/attendance_screen.dart';

Future<void> _pump(WidgetTester tester, Widget child, {double width = 300}) {
  return tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    ),
  ));
}

void main() {
  group('AttendanceProgressLine.status', () {
    test('nothing recorded', () {
      expect(AttendanceProgressLine.status(0, 10),
          (AppStrings.notTakenYet, AppColors.warning));
    });
    test('some recorded', () {
      expect(AttendanceProgressLine.status(4, 10),
          (AppStrings.partlyTaken, AppColors.coral));
    });
    test('all recorded', () {
      expect(AttendanceProgressLine.status(10, 10),
          (AppStrings.takenDone, AppColors.success));
    });
  });

  group('AttendanceProgressLine', () {
    testWidgets('shows the count, the total and the status on one line',
        (tester) async {
      await _pump(
        tester,
        const AttendanceProgressLine(present: 2, recorded: 80, total: 80),
      );
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('80'), findsOneWidget);
      expect(find.text(AppStrings.takenDone), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(2 / 80, 0.001));
    });

    testWidgets('fits a narrow phone with the ⋮ menu, no overflow',
        (tester) async {
      // About the header's inner width on a 320 px phone.
      await _pump(
        tester,
        AttendanceProgressLine(
          present: 188,
          recorded: 120,
          total: 200,
          trailing: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
          ),
        ),
        width: 276,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.partlyTaken), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('an empty class shows an empty bar', (tester) async {
      await _pump(
        tester,
        const AttendanceProgressLine(present: 0, recorded: 0, total: 0),
      );
      await tester.pumpAndSettle();
      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, 0);
      expect(find.text(AppStrings.notTakenYet), findsOneWidget);
    });
  });
}
