import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/app_notification.dart';
import 'package:sabtawya/features/settings/absence_alert_tile.dart';

void main() {
  group('AppNotification', () {
    test('reads the child an absence alert is about', () {
      final n = AppNotification.fromMap({
        'id': 'n1',
        'kind': 'absence_child',
        'title': 'مخدوم غايب',
        'body': 'مينا غاب سبتين ورا بعض',
        'created_at': '2026-11-18T10:00:00Z',
        'ref_id': 'class-1',
        'child_id': 'child-1',
      });
      expect(n.childId, 'child-1');
      expect(n.refId, 'class-1');
    });

    test('older entries have no child', () {
      final n = AppNotification.fromMap({
        'id': 'n2',
        'kind': 'child_added',
        'title': 't',
        'body': 'b',
        'created_at': '2026-11-18T10:00:00Z',
      });
      expect(n.childId, isNull);
    });
  });

  group('alert levels', () {
    test('accepts one to four numbers between 1 and 20', () {
      expect(AbsenceAlertTile.parseLevels('2,3'), [2, 3]);
      expect(AbsenceAlertTile.parseLevels(' 3 ، 2 '), [2, 3]);
      expect(AbsenceAlertTile.parseLevels('2,2,3'), [2, 3]);
      expect(AbsenceAlertTile.parseLevels('4'), [4]);
    });

    test('refuses anything else', () {
      expect(AbsenceAlertTile.parseLevels(''), isNull);
      expect(AbsenceAlertTile.parseLevels('0'), isNull);
      expect(AbsenceAlertTile.parseLevels('21'), isNull);
      expect(AbsenceAlertTile.parseLevels('a,2'), isNull);
      expect(AbsenceAlertTile.parseLevels('1,2,3,4,5'), isNull);
    });
  });

  testWidgets('the settings tile shows the stored levels and refuses bad input',
      (tester) async {
    var saved = '';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AbsenceAlertTile(
              load: () async => '2,4',
              save: (v) async => saved = v,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('2,4'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(saved, '');
    expect(find.text('اكتب من رقم إلى 4 أرقام بين 1 و20 مفصولة بفاصلة'),
        findsOneWidget);
  });
}
