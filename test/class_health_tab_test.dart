import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/class_health.dart';
import 'package:sabtawya/features/classes/class_health_tab.dart';

ClassHealth _health(String name, {int taken = 10, int absent = 0}) =>
    ClassHealth(
      classId: name,
      className: name,
      servantsCount: 2,
      activeChildren: 12,
      held: 10,
      taken: taken,
      takenLate: 0,
      presentPct: 80,
      prepExpected: 20,
      prepSubmitted: 20,
      prepAccepted: 20,
      absent2plus: absent,
      absentFollowed: 0,
    );

Future<void> _pump(
  WidgetTester tester,
  Future<List<ClassHealth>> Function() load, {
  bool everyClass = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: ClassHealthTab(load: load, everyClass: everyClass),
        ),
      ),
    ),
  );
  // The empty and error views loop an animation, so never "settle".
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('shows every class with its score, title for the admin',
      (tester) async {
    await _pump(
      tester,
      () async => [_health('5 ولاد'), _health('3 بنات', taken: 4, absent: 6)],
    );
    expect(find.text(AppStrings.classHealthTitle), findsOneWidget);
    expect(find.textContaining('5 ولاد'), findsOneWidget);
    expect(find.textContaining('3 بنات'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
  });

  testWidgets('a servant sees "صحة فصلي"', (tester) async {
    await _pump(tester, () async => [_health('5 ولاد')], everyClass: false);
    expect(find.text(AppStrings.myClassHealthTitle), findsOneWidget);
  });

  testWidgets('nothing yet shows the empty state', (tester) async {
    await _pump(tester, () async => const <ClassHealth>[]);
    expect(find.text(AppStrings.noClassHealth), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    var calls = 0;
    await _pump(tester, () async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return [_health('5 ولاد')];
    });
    expect(find.textContaining('5 ولاد'), findsNothing);
    expect(find.text(AppStrings.retry), findsOneWidget);
    await tester.tap(find.text(AppStrings.retry));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('5 ولاد'), findsOneWidget);
  });
}
