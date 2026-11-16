import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/widgets/whatsapp_icon.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/children/birthday_whatsapp_button.dart';

Child _child({String? mother}) => Child(
      id: 'c',
      classId: 'k',
      fullName: 'مينا',
      gender: Gender.boy,
      isActive: true,
      motherMobile: mother,
    );

Widget _app(BirthdayWhatsAppButton button) =>
    MaterialApp(home: Scaffold(body: Center(child: button)));

void main() {
  testWidgets('shows the WhatsApp logo for a number WhatsApp can reach',
      (tester) async {
    await tester.pumpWidget(_app(const BirthdayWhatsAppButton(
      name: 'مينا',
      servantName: 'أبانوب',
      ownMobile: '01012345678',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(WhatsAppIcon), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
  });

  testWidgets('a child with no number of their own uses the mother\'s',
      (tester) async {
    await tester.pumpWidget(_app(BirthdayWhatsAppButton(
      name: 'مينا',
      servantName: 'أبانوب',
      ownMobile: null,
      child: _child(mother: '01012345678'),
    )));
    await tester.pumpAndSettle();

    expect(find.byType(WhatsAppIcon), findsOneWidget);
  });

  testWidgets('nothing to write to: no button at all', (tester) async {
    await tester.pumpWidget(_app(BirthdayWhatsAppButton(
      name: 'مينا',
      servantName: 'أبانوب',
      ownMobile: '0222222222',
      child: _child(),
    )));
    await tester.pumpAndSettle();

    expect(find.byType(WhatsAppIcon), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('the compact button is the small one', (tester) async {
    await tester.pumpWidget(_app(const BirthdayWhatsAppButton(
      name: 'مينا',
      servantName: 'أبانوب',
      ownMobile: '01012345678',
      compact: true,
    )));
    await tester.pumpAndSettle();

    final icon = tester.widget<WhatsAppIcon>(find.byType(WhatsAppIcon));
    expect(icon.size, 18);
  });
}
