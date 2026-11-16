import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/utils/app_date_utils.dart';
import 'package:sabtawya/features/children/change_history_card.dart';
import 'package:sabtawya/data/models/child.dart';

ChildChange c(String at,
        {String? by,
        String entity = 'children',
        String action = 'update',
        List<String> changed = const []}) =>
    ChildChange(
        createdAt: DateTime.parse(at),
        action: action,
        entity: entity,
        actorName: by,
        changed: changed);

final now = DateTime(2026, 11, 16, 20);

Future<void> pump(WidgetTester tester, List<ChildChange> changes) async {
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(
          child: ChangeHistoryCard(changes: changes, now: now),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  // The card starts closed, like the other logs on the page.
  await tester.tap(find.text(AppStrings.changeHistory));
  await tester.pumpAndSettle();
}

void main() {
  test('day label: today, yesterday, a weekday, and the year when it differs',
      () {
    expect(AppDateUtils.dayLabel(DateTime(2026, 11, 16, 9), now: now), 'اليوم');
    expect(AppDateUtils.dayLabel(DateTime(2026, 11, 15, 23), now: now), 'أمس');
    expect(AppDateUtils.dayLabel(DateTime(2026, 11, 13), now: now),
        'الجمعة 13 نوفمبر');
    expect(AppDateUtils.dayLabel(DateTime(2025, 12, 27), now: now),
        'السبت 27 ديسمبر 2025');
  });

  test('time of day in 12 hours', () {
    expect(AppDateUtils.formatTime(DateTime(2026, 11, 16, 20, 5)), '08:05 م');
    expect(AppDateUtils.formatTime(DateTime(2026, 11, 16, 0, 30)), '12:30 ص');
  });

  testWidgets('one heading per day, who, what, the fields and the time',
      (tester) async {
    await pump(tester, [
      c('2026-11-16T09:15:00', by: 'فارس صبحي', changed: ['mother_mobile']),
      c('2026-11-16T08:00:00',
          by: 'فارس صبحي', changed: ['address', 'mother_mobile']),
      c('2026-11-13T18:30:00', by: 'مينا جورج', entity: 'attendance_records'),
      c('2026-11-13T10:00:00', by: 'مينا جورج', action: 'insert'),
    ]);

    // Two saves by the same person on one day are one entry.
    expect(find.text('فارس صبحي'), findsOneWidget);
    expect(find.text('اليوم'), findsOneWidget);
    expect(find.text('09:15 ص'), findsOneWidget);
    expect(find.text('رقم الأم'), findsOneWidget);
    expect(find.text('العنوان'), findsOneWidget);
    expect(find.text(AppStrings.changeEdited), findsOneWidget);

    // The older day has one heading for its two entries.
    expect(find.text('الجمعة 13 نوفمبر'), findsOneWidget);
    expect(find.text('· منذ 3 أيام'), findsOneWidget);
    expect(find.text('مينا جورج'), findsNWidgets(2));
    expect(find.text(AppStrings.changeAttendance), findsOneWidget);
    expect(find.text(AppStrings.changeAdded), findsOneWidget);
  });

  testWidgets('no name shows the system; five entries first, then all',
      (tester) async {
    await pump(tester, [
      for (var d = 14; d >= 8; d--)
        c('2026-11-${d.toString().padLeft(2, '0')}T10:00:00'),
    ]);

    expect(find.text('النظام'), findsNWidgets(5));
    await tester.tap(find.text(AppStrings.showAllCount(7)));
    await tester.pumpAndSettle();
    expect(find.text('النظام'), findsNWidgets(7));
    expect(find.text(AppStrings.showLess), findsOneWidget);
  });
}
