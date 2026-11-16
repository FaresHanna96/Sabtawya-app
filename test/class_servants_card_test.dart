import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/widgets/whatsapp_icon.dart';
import 'package:sabtawya/data/models/profile.dart';
import 'package:sabtawya/features/classes/class_servants_card.dart';

ClassServant _servant(
  String id,
  String name, {
  String? mobile,
  bool active = true,
}) =>
    ClassServant(
      assignmentId: 'a$id',
      classId: 'c',
      className: '3 ولاد',
      servantId: id,
      servantName: name,
      servantIsActive: active,
      servantMobile: mobile,
    );

Widget _app(List<ClassServant> servants, {String? me}) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: ClassServantsCard(servants: servants, currentUserId: me),
          ),
        ),
      ),
    );

void main() {
  testWidgets('one row per servant, with the count in the title row',
      (tester) async {
    await tester.pumpWidget(_app([
      _servant('1', 'ناهد يسرى شوقى', mobile: '01011111111'),
      _servant('2', 'مريم نبيل طانيوس', mobile: '01022222222'),
      _servant('3', 'أنا سيمون كيرلس'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('الخدام المعينون'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // the count
    expect(find.byType(ServantRow), findsNWidgets(3));
    expect(find.text('ناهد يسرى شوقى'), findsOneWidget);
  });

  testWidgets('shows the first letter of each name in the avatar',
      (tester) async {
    await tester.pumpWidget(_app([_servant('1', 'مريم نبيل')]));
    await tester.pumpAndSettle();

    expect(find.text('م'), findsOneWidget);
    expect(ServantRow.initialOf('  ناهد'), 'ن');
    expect(ServantRow.initialOf(''), '؟');
  });

  test('a servant always has the same colour', () {
    expect(ServantRow.colorFor('مريم نبيل'), ServantRow.colorFor('مريم نبيل'));
    final colours = {
      for (final n in ['ناهد', 'مريم', 'أنا', 'مينا', 'بولا', 'سارة'])
        ServantRow.colorFor(n),
    };
    expect(colours.length, greaterThan(1));
  });

  testWidgets('call and WhatsApp for a servant with a mobile number',
      (tester) async {
    await tester
        .pumpWidget(_app([_servant('1', 'ناهد', mobile: '01011111111')]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.byType(WhatsAppIcon), findsOneWidget);
  });

  testWidgets('a landline gets only the call button', (tester) async {
    await tester
        .pumpWidget(_app([_servant('1', 'ناهد', mobile: '0222222222')]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.byType(WhatsAppIcon), findsNothing);
  });

  testWidgets('no number: no buttons', (tester) async {
    await tester.pumpWidget(
        _app([_servant('1', 'ناهد'), _servant('2', 'مريم', mobile: '  ')]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.call_rounded), findsNothing);
    expect(find.byType(WhatsAppIcon), findsNothing);
  });

  testWidgets('your own row says so and has no buttons to call yourself',
      (tester) async {
    await tester.pumpWidget(_app(
      [
        _servant('1', 'ناهد', mobile: '01011111111'),
        _servant('2', 'مريم', mobile: '01022222222'),
      ],
      me: '1',
    ));
    await tester.pumpAndSettle();

    expect(find.text('أنت'), findsOneWidget);
    // Only the other servant can be called.
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.byType(WhatsAppIcon), findsOneWidget);
  });

  testWidgets('a servant whose account is off is marked and quieter',
      (tester) async {
    await tester.pumpWidget(_app([_servant('1', 'ناهد', active: false)]));
    await tester.pumpAndSettle();

    expect(find.text('غير مفعّل'), findsOneWidget);
    // Somewhere above the name is the dimming of an inactive row (the page's
    // own entrance animations add other Opacity widgets).
    final dims = tester
        .widgetList<Opacity>(find.ancestor(
          of: find.text('ناهد'),
          matching: find.byType(Opacity),
        ))
        .map((o) => o.opacity);
    expect(dims, contains(lessThan(1.0)));
  });

  testWidgets('no servants: a plain line, no count', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();

    expect(find.text('لا يوجد خدام'), findsOneWidget);
    expect(find.byType(ServantRow), findsNothing);
  });

  testWidgets('long names and a narrow phone do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app([
      _servant('1', 'اناسيمون ممدوح بشري عبد المسيح جرجس مينا',
          mobile: '01011111111'),
    ]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
