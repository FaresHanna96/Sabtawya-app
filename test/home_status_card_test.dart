import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/features/dashboard/home_status_card.dart';
import 'package:sabtawya/features/dashboard/quick_action_grid.dart';
import 'package:sabtawya/features/dashboard/today_birthdays_section.dart';

Future<void> _pump(WidgetTester t, Widget w, {double width = 340}) =>
    t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Center(child: SizedBox(width: width, child: w)),
          ),
        ),
      ),
    ));

void main() {
  group('HomeStatusCard', () {
    testWidgets('the name and year, the greeting, and the totals',
        (t) async {
      await _pump(
        t,
        const HomeStatusCard(
          name: 'مينا',
          yearName: '2026 / 2027',
          totals: [
            HomeTotal(
              value: 80,
              label: AppStrings.totalChildren,
              sub: '40 أولاد • 40 بنات',
            ),
          ],
        ),
      );
      expect(find.text('مينا'), findsOneWidget);
      expect(find.text('2026 / 2027'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text(AppStrings.totalChildren), findsOneWidget);
      expect(find.text('40 أولاد • 40 بنات'), findsOneWidget);
      expect(find.text(AppStrings.homeRecordNow), findsNothing);
    });

    testWidgets('how the last Saturday went is not repeated here',
        (t) async {
      await _pump(t, const HomeStatusCard(name: 'مينا'));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('«سجّل الحضور» shows when a class still has to record',
        (t) async {
      var tapped = 0;
      await _pump(
        t,
        HomeStatusCard(name: 'م', onRecord: () => tapped++),
      );
      await t.tap(find.text(AppStrings.homeRecordNow));
      expect(tapped, 1);
    });

    testWidgets('fits a narrow phone with the sub lines', (t) async {
      await _pump(
        t,
        HomeStatusCard(
          name: 'أمين خدمة تجريبي طويل الاسم',
          yearName: '2026 / 2027',
          onRecord: () {},
          totals: const [
            HomeTotal(
              value: 80,
              label: AppStrings.totalChildren,
              sub: '40 أولاد • 40 بنات',
            ),
            HomeTotal(value: 8, label: AppStrings.totalClasses),
            HomeTotal(
              value: 1,
              label: AppStrings.totalServants,
              sub: '1 أمناء',
            ),
          ],
        ),
        width: 288,
      );
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('BirthdaySections: each group, its count, no folding inside',
      (t) async {
    await _pump(
      t,
      const BirthdaySections(children: [
        (title: 'المخدومين', count: 2, content: Text('قائمة المخدومين')),
        (title: 'الخدام', count: 1, content: Text('قائمة الخدام')),
      ]),
    );
    expect(find.text('المخدومين'), findsOneWidget);
    expect(find.text('قائمة المخدومين'), findsOneWidget);
    expect(find.text('قائمة الخدام'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    expect(find.byIcon(Icons.expand_less_rounded), findsNothing);
  });

  testWidgets('CompactBirthdays: one line, the lists on a tap', (t) async {
    await _pump(
      t,
      const CompactBirthdays(
        childCount: 2,
        servantCount: 1,
        details: Text('القوائم'),
      ),
    );
    expect(find.textContaining(AppStrings.birthdaysToday), findsOneWidget);
    expect(find.textContaining('2 مخدوم'), findsOneWidget);
    expect(find.text('القوائم'), findsNothing);
    await t.tap(find.textContaining(AppStrings.birthdaysToday));
    await t.pumpAndSettle();
    expect(find.text('القوائم'), findsOneWidget);
  });

  group('QuickActionGrid compact', () {
    testWidgets('a small titled section with slim buttons', (t) async {
      await _pump(
        t,
        QuickActionGrid(
          compact: true,
          actions: [
            QuickAction(Icons.add, 'إضافة', Colors.blue, () {}),
            QuickAction(Icons.event, 'التقويم', Colors.orange, () {}),
          ],
        ),
      );
      expect(find.text('إضافة'), findsOneWidget);
      expect(find.text(AppStrings.quickActions), findsOneWidget);
      expect(t.getSize(find.byType(InkWell).first).height, 44);
    });

    testWidgets('three go two to a row, the last spanning, no label cut',
        (t) async {
      await _pump(
        t,
        QuickActionGrid(
          compact: true,
          actions: [
            QuickAction(Icons.add, 'إضافة مخدوم', Colors.green, () {}),
            QuickAction(Icons.event, 'نشاطات ترفيهية', Colors.red, () {}),
            QuickAction(Icons.today, 'التقويم', Colors.orange, () {}),
          ],
        ),
        width: 330,
      );
      final a = t.getTopLeft(find.text('إضافة مخدوم')).dy;
      final b = t.getTopLeft(find.text('نشاطات ترفيهية')).dy;
      final c = t.getTopLeft(find.text('التقويم')).dy;
      expect(a, b); // the first two share a row
      expect(c, greaterThan(a)); // the third is on the next
      // Full words, not «إضافة مخد…».
      final text = t.widget<Text>(find.text('إضافة مخدوم'));
      expect(text.maxLines, 2);
      expect(t.takeException(), isNull);
    });

    testWidgets('more than four still use the titled card', (t) async {
      await _pump(
        t,
        QuickActionGrid(
          compact: true,
          actions: [
            for (var i = 0; i < 5; i++)
              QuickAction(Icons.add, 'عمل $i', Colors.blue, () {}),
          ],
        ),
      );
      expect(find.text(AppStrings.quickActions), findsOneWidget);
    });
  });
}
