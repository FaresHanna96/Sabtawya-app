import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/widgets/app_widgets.dart';
import 'package:sabtawya/core/widgets/whatsapp_icon.dart';

Widget _row(String? value, {bool isPhone = true}) => MaterialApp(
      home: Scaffold(
        body: InfoRow(label: 'رقم', value: value, isPhone: isPhone),
      ),
    );

void main() {
  testWidgets('a mobile number gets a call button and the WhatsApp logo',
      (tester) async {
    await tester.pumpWidget(_row('01012345678'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.call), findsOneWidget);
    expect(find.byType(WhatsAppIcon), findsOneWidget);
  });

  testWidgets('a number WhatsApp cannot reach still gets the call button only',
      (tester) async {
    await tester.pumpWidget(_row('0222222222')); // a landline
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.call), findsOneWidget);
    expect(find.byType(WhatsAppIcon), findsNothing);
  });

  testWidgets('no number, or a row that is not a phone, has neither',
      (tester) async {
    await tester.pumpWidget(_row(null));
    await tester.pumpAndSettle();
    expect(find.byType(WhatsAppIcon), findsNothing);
    expect(find.byIcon(Icons.call), findsNothing);

    await tester.pumpWidget(_row('01012345678', isPhone: false));
    await tester.pumpAndSettle();
    expect(find.byType(WhatsAppIcon), findsNothing);
    expect(find.byIcon(Icons.call), findsNothing);
  });

  testWidgets('a phone number stays on one line beside both buttons',
      (tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_row('01099887766'));
    await tester.pumpAndSettle();

    final number = find.text('01099887766');
    expect(number, findsOneWidget);
    // One line: the text box is no taller than a single line of 14px text.
    expect(tester.getSize(number).height, lessThan(24));
  });
}
