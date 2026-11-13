import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/widgets/unsaved_changes_guard.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/features/dashboard/weekly_attendance_chart.dart';

Widget _app(bool dirty) => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => UnsavedChangesGuard(
                    dirty: dirty,
                    child: const Scaffold(body: Text('form')),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  group('UnsavedChangesGuard', () {
    testWidgets('a clean form closes at once', (tester) async {
      await tester.pumpWidget(_app(false));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('form'), findsNothing);
    });

    testWidgets('a changed form asks, and stays when not discarded',
        (tester) async {
      await tester.pumpWidget(_app(true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.unsavedChanges), findsOneWidget);
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.text('form'), findsOneWidget);
    });

    testWidgets('discarding closes the form', (tester) async {
      await tester.pumpWidget(_app(true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.discard));
      await tester.pumpAndSettle();
      expect(find.text('form'), findsNothing);
    });
  });

  test('weekly chart keeps the last ten Saturdays, oldest first', () {
    final all = [
      for (var i = 0; i < 14; i++)
        WeeklyAttendance(
          date: DateTime(2026, 9, 5).add(Duration(days: 7 * i)),
          present: i,
          children: 20,
        ),
    ];
    final shown = WeeklyAttendanceChart.lastWeeks(all);
    expect(shown, hasLength(10));
    expect(shown.first.present, 4);
    expect(shown.last.present, 13);
    expect(shown.last.percentage, 65);
  });

  test('activity rate is out of the Saturdays held', () {
    const r = ChildActivityRate(
      childId: 'c',
      childName: 'مينا',
      classId: 'k',
      className: '5 ولاد',
      held: 7,
      sundaySchool: 7,
      vespers: 0,
      mass: 3,
      confession: 1,
    );
    expect(r.counts, [7, 0, 3, 1]);
    expect(r.rate(7), 100);
    expect(r.rate(0), 0);
  });
}
