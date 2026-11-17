import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/features/children/health_notes_card.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );

void main() {
  group('who sees the health notes', () {
    bool visible({
      bool admin = false,
      bool general = false,
      List<String> mine = const [],
      String cls = 'c1',
    }) =>
        healthNotesVisible(
          isAdmin: admin,
          isGeneralServant: general,
          myClassIds: mine,
          classId: cls,
        );

    test('an admin sees every class', () {
      expect(visible(admin: true), isTrue);
    });

    test('a servant sees only their own class', () {
      expect(visible(mine: ['c1']), isTrue);
      expect(visible(mine: ['c2']), isFalse);
    });

    test('the general servant never sees them', () {
      expect(visible(general: true, mine: ['c1']), isFalse);
      expect(visible(general: true, admin: true), isFalse);
    });
  });

  group('HealthNotesCard', () {
    testWidgets('shows the saved note', (tester) async {
      await tester.pumpWidget(_app(HealthNotesCard(
        childId: 'k',
        load: (_) async => 'حساسية من الفول',
        save: (_, __) async {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('حساسية من الفول'), findsOneWidget);
    });

    testWidgets('says so when there is no note', (tester) async {
      await tester.pumpWidget(_app(HealthNotesCard(
        childId: 'k',
        load: (_) async => null,
        save: (_, __) async {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد ملاحظات'), findsOneWidget);
    });

    testWidgets('editing shows a cancel and a save button that fit',
        (tester) async {
      await tester.pumpWidget(_app(HealthNotesCard(
        childId: 'k',
        load: (_) async => 'ربو',
        save: (_, __) async {},
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // The default theme has a full-width FilledButton; with the app's own
      // theme inside a Row that threw and drew nothing.
      expect(tester.takeException(), isNull);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('حفظ'), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)).width, lessThan(300));
    });

    testWidgets('a failed load offers a retry, not an empty note',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(_app(HealthNotesCard(
        childId: 'k',
        load: (_) async {
          calls++;
          if (calls == 1) throw Exception('offline');
          return 'ربو';
        },
        save: (_, __) async {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد ملاحظات'), findsNothing);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(find.text('ربو'), findsOneWidget);
    });
  });
}
