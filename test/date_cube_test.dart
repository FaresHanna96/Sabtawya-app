import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/core/utils/app_date_utils.dart';
import 'package:sabtawya/core/widgets/date_cube.dart';

void main() {
  testWidgets('shows the day number over the month name', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: DateCube(date: DateTime(2026, 11, 28), color: AppColors.gold),
        ),
      ),
    ));
    expect(find.text('28'), findsOneWidget);
    expect(find.text(AppDateUtils.monthName(11)), findsOneWidget);
  });

  testWidgets('stays 52 wide whatever the month name', (tester) async {
    for (final m in [1, 9, 12]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: DateCube(date: DateTime(2026, m, 5), color: AppColors.sky),
          ),
        ),
      ));
      expect(tester.getSize(find.byType(DateCube)).width, 52);
      expect(tester.takeException(), isNull);
    }
  });
}
