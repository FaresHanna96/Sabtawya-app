import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/features/dashboard/weekly_attendance_chart.dart';

void main() {
  final weeks = [
    for (var i = 0; i < 10; i++)
      WeeklyAttendance(
        date: DateTime(2026, 9, 5).add(Duration(days: 7 * i)),
        present: 40 + i * 3,
        children: 148,
      ),
  ];

  testWidgets('10 Saturdays fit a phone and a tap shows that Saturday',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: WeeklyAttendanceChart(weeks: weeks),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Newest first: 67 of 148.
    expect(find.text('67 من 148 مخدوم'), findsOneWidget);
    expect(find.textContaining('أعلى 2% من السبت اللي قبله'), findsOneWidget);
    // Tap the oldest bar's date.
    await tester.tap(find.text('5/9'));
    await tester.pumpAndSettle();
    expect(find.text('سبت 5/9: حضر 40 من 148 (27%)'), findsOneWidget);
  });

  test('level colours: green 60+, amber 40+, red below', () {
    expect(WeeklyAttendanceChart.levelColor(60), AppColors.success);
    expect(WeeklyAttendanceChart.levelColor(45), AppColors.warning);
    expect(WeeklyAttendanceChart.levelColor(39), AppColors.danger);
  });
}
