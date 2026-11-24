import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/features/servant_activities/servant_summary_card.dart';

Widget _card({int? prepSessions}) => MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: ServantSummaryCard(
              sundaySchool: 8,
              servantMeeting: 4,
              mass: 3,
              confession: 2,
              preps: 1,
              pendingPreps: 0,
              heldSessions: 8,
              prepSessions: prepSessions,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('the prep is out of the Saturdays with a lesson, not the '
      'نشاط ترفيهي ones', (tester) async {
    // 8 Saturdays held, one of them a نشاط ترفيهي: 7 can have a prep.
    await tester.pumpWidget(_card(prepSessions: 7));
    expect(find.text('1/7'), findsOneWidget);
    // The four activities still divide by all 8.
    expect(find.text('8/8'), findsOneWidget);
  });

  testWidgets('without the activity count the prep uses all Saturdays',
      (tester) async {
    await tester.pumpWidget(_card());
    expect(find.text('1/8'), findsOneWidget);
  });
}
