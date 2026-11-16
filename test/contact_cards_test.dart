import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/widgets/whatsapp_icon.dart';
import 'package:sabtawya/features/children/contact_cards.dart';

Widget _app(List<ContactPerson> people, {double width = 375}) => MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: width - 32,
              child: ContactCards(
                people: people,
                childName: 'مينا',
                servantName: 'أبانوب',
              ),
            ),
          ),
        ),
      ),
    );

const _all = [
  ContactPerson('المخدوم', '01099887766'),
  ContactPerson('الأم', '+201012345678'),
  ContactPerson('الأب', '0222222222'), // a landline
];

void main() {
  testWidgets('one row per person, with the label and the number',
      (tester) async {
    await tester.pumpWidget(_app(_all));
    await tester.pumpAndSettle();

    for (final text in [
      'المخدوم',
      'الأم',
      'الأب',
      '01099887766',
      '+201012345678',
      '0222222222',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('everybody can be called, only mobiles get WhatsApp',
      (tester) async {
    await tester.pumpWidget(_app(_all));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.call_rounded), findsNWidgets(3));
    // The landline has the call button only.
    expect(find.byType(WhatsAppIcon), findsNWidgets(2));
  });

  testWidgets('the buttons are big enough for a thumb', (tester) async {
    await tester.pumpWidget(_app(_all));
    await tester.pumpAndSettle();

    final call = tester.getSize(find
        .ancestor(
          of: find.byIcon(Icons.call_rounded).first,
          matching: find.byType(SizedBox),
        )
        .first);
    expect(call.width, greaterThanOrEqualTo(48));
    expect(call.height, greaterThanOrEqualTo(48));
  });

  testWidgets('no overflow on a narrow phone with three rows', (tester) async {
    await tester.pumpWidget(_app(_all, width: 320));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('one person is one row; nobody shows nothing', (tester) async {
    await tester.pumpWidget(_app(const [ContactPerson('الأم', '01012345678')]));
    await tester.pumpAndSettle();
    expect(find.text('الأم'), findsOneWidget);
    expect(find.byType(WhatsAppIcon), findsOneWidget);

    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.byType(WhatsAppIcon), findsNothing);
    expect(find.byIcon(Icons.call_rounded), findsNothing);
  });
}
