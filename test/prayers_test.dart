import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/features/home/more_entries.dart';
import 'package:sabtawya/features/prayers/prayers.dart';
import 'package:sabtawya/features/prayers/prayers_screen.dart';

Widget _app(Widget home) => MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: home),
    );

void main() {
  group('صلوات in المزيد', () {
    test('every role sees it, under الخدمة', () {
      for (final role in MoreRole.values) {
        final e = MoreCatalog.entriesFor(role).where((e) => e.id == 'prayers');
        expect(e, hasLength(1), reason: '$role');
        expect(e.single.group, MoreGroup.service);
      }
    });

    test('search finds it by صلاة and by spelling variants', () {
      final all = MoreCatalog.entriesFor(MoreRole.servant);
      for (final q in ['صلاة', 'صلوات', 'صلاه', 'قبل الخدمه']) {
        expect(MoreCatalog.search(all, q).map((e) => e.id), contains('prayers'),
            reason: q);
      }
    });
  });

  group('the prayers', () {
    test('before and after, each ending in آمين', () {
      expect(Prayers.all.map((p) => p.title),
          ['صلاة قبل الخدمة', 'صلاة بعد الخدمة']);
      for (final p in Prayers.all) {
        expect(p.paragraphs, isNotEmpty);
        expect(p.paragraphs.last, contains('آمين'));
      }
    });

    testWidgets('the list opens a prayer', (tester) async {
      await tester.pumpWidget(_app(const PrayersScreen()));
      expect(find.text('صلاة قبل الخدمة'), findsOneWidget);
      expect(find.text('صلاة بعد الخدمة'), findsOneWidget);

      await tester.tap(find.text('صلاة بعد الخدمة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('أيها الرب الإله الذي يحب كل أحد'),
          findsOneWidget);
    });

    testWidgets('the text grows and shrinks within its limits',
        (tester) async {
      await tester.pumpWidget(
          _app(const PrayerScreen(prayer: Prayers.beforeService)));
      double size() => tester
          .widget<Text>(find.textContaining('أيها الرب العارف'))
          .style!
          .fontSize!;

      final start = size();
      await tester.tap(find.byIcon(Icons.text_increase_rounded));
      await tester.pump();
      expect(size(), start + 2);

      for (var i = 0; i < 20; i++) {
        await tester.tap(find.byIcon(Icons.text_decrease_rounded));
        await tester.pump();
      }
      expect(size(), PrayerScreen.minSize);
    });
  });
}
