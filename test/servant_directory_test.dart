import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/widgets/whatsapp_icon.dart';
import 'package:sabtawya/data/models/profile.dart';
import 'package:sabtawya/features/servants/servant_directory_screen.dart';

Widget host(ServantContact s) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: ServantContactCard(servant: s)),
      ),
    );

void main() {
  test('reads a directory row: role, gender, classes and mobile only', () {
    final s = ServantContact.fromMap({
      'id': 'a',
      'full_name': 'مريم',
      'role': 'servant',
      'gender': 'girl',
      'mobile': '01012345678',
      'class_names': ['أولى', 'ثانية'],
    });
    expect(s.roleLabel, AppStrings.roleServantFemale);
    expect(s.classNames, ['أولى', 'ثانية']);
    expect(s.mobile, '01012345678');
  });

  test('a row without classes or mobile still reads', () {
    final s = ServantContact.fromMap({'id': 'a', 'full_name': 'مينا'});
    expect(s.classNames, isEmpty);
    expect(s.mobile, isNull);
  });

  testWidgets('shows name, classes, and only call and WhatsApp', (t) async {
    await t.pumpWidget(host(const ServantContact(
      id: 'a',
      fullName: 'مريم جورج',
      role: AppRole.servant,
      classNames: ['أولى', 'ثانية'],
      mobile: '01012345678',
    )));
    expect(find.text('مريم جورج'), findsOneWidget);
    expect(find.textContaining('أولى، ثانية'), findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.byType(WhatsAppIcon), findsOneWidget);
    // The number itself is not printed, nor any other action.
    expect(find.textContaining('01012345678'), findsNothing);
    expect(find.byType(IconButton), findsNWidgets(2));
  });

  testWidgets('no mobile: no icons, a short note', (t) async {
    await t.pumpWidget(host(const ServantContact(
      id: 'a',
      fullName: 'مينا',
      role: AppRole.servant,
      classNames: [],
    )));
    expect(find.byType(IconButton), findsNothing);
    expect(find.text(AppStrings.noServantMobile), findsOneWidget);
  });
}
