import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/widgets/whatsapp_icon.dart';

void main() {
  testWidgets('draws the WhatsApp mark at the size asked, from the app assets',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: WhatsAppIcon(size: 30))),
    ));
    await tester.pumpAndSettle();

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(picture.width, 30);
    expect(picture.height, 30);
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('WhatsApp'), findsOneWidget);
  });

  test('it is WhatsApp\'s brand green', () {
    expect(WhatsAppIcon.green, const Color(0xFF25D366));
  });
}
