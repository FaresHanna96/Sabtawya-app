import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/whatsapp.dart';
import 'package:sabtawya/core/widgets/whatsapp_icon.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/children/missing_info.dart';
import 'package:sabtawya/features/children/missing_info_screen.dart';

/// A child with everything filled in, which each test then empties.
Child _full({
  String id = 'k',
  String name = 'مينا',
  DateTime? birth,
  String? mobile = '01011111111',
  String? mother = 'أم مينا',
  String? motherMobile = '01022222222',
  String? father = 'أب مينا',
  String? fatherMobile = '01033333333',
  String? confession = 'أبونا بولس',
  String? school = 'مدرسة',
  String? address = 'مدينة نصر',
  bool noBirth = false,
}) =>
    Child(
      id: id,
      classId: 'c1',
      fullName: name,
      gender: Gender.boy,
      isActive: true,
      birthDate: noBirth ? null : (birth ?? DateTime(2016, 3, 9)),
      mobile: mobile,
      motherName: mother,
      motherMobile: motherMobile,
      fatherName: father,
      fatherMobile: fatherMobile,
      confessionFather: confession,
      school: school,
      address: address,
    );

void main() {
  group('what is missing from a child', () {
    test('a complete record misses nothing', () {
      expect(MissingInfo.of(_full()), isEmpty);
    });

    test('the birthday', () {
      expect(MissingInfo.of(_full(noBirth: true)), [MissingField.birthDate]);
    });

    test('a blank or spaces-only text counts as missing', () {
      expect(
        MissingInfo.of(_full(
            mother: '   ',
            father: '',
            confession: null,
            school: ' ',
            address: '')),
        [
          MissingField.mother,
          MissingField.father,
          MissingField.confessionFather,
          MissingField.school,
          MissingField.address,
        ],
      );
    });

    test('a phone is missing only when nobody can be reached', () {
      // The child has none, but a parent has: reachable.
      expect(
        MissingInfo.of(_full(mobile: null, motherMobile: null)),
        isEmpty,
      );
      expect(
        MissingInfo.of(
            _full(mobile: '', motherMobile: ' ', fatherMobile: null)),
        [MissingField.phone],
      );
    });

    test('several gaps come in the order the list shows them', () {
      expect(
        MissingInfo.of(_full(noBirth: true, school: null, mother: null)),
        [MissingField.birthDate, MissingField.mother, MissingField.school],
      );
    });
  });

  group('counting and filtering a class', () {
    final children = [
      _full(id: '1', noBirth: true),
      _full(id: '2', noBirth: true, school: null),
      _full(id: '3', school: null),
      _full(id: '4'),
    ];

    test('how many miss each field', () {
      final counts = MissingInfo.counts(children);
      expect(counts[MissingField.birthDate], 2);
      expect(counts[MissingField.school], 2);
      expect(counts[MissingField.phone], 0);
      expect(counts.keys, MissingField.values);
    });

    test('the children missing one field', () {
      expect(
        MissingInfo.filter(children, MissingField.birthDate).map((c) => c.id),
        ['1', '2'],
      );
    });

    test('the children missing anything', () {
      expect(
          MissingInfo.filter(children, null).map((c) => c.id), ['1', '2', '3']);
    });

    test('nothing missing anywhere', () {
      expect(MissingInfo.filter([_full()], null), isEmpty);
      expect(MissingInfo.counts(const <Child>[])[MissingField.birthDate], 0);
    });
  });

  group('asking the family on WhatsApp', () {
    test('names the servant, the child and what is needed', () {
      final text = WhatsApp.missingInfoMessage(
        childName: 'مينا عادل',
        servantName: 'أبانوب',
        missing: ['تاريخ الميلاد', 'المدرسة'],
      );
      expect(text, contains('أبانوب'));
      expect(text, contains('مينا عادل'));
      expect(text, contains('تاريخ الميلاد، المدرسة'));
    });

    test('still reads with no servant name and nothing listed', () {
      final text = WhatsApp.missingInfoMessage(
          childName: 'مينا', servantName: ' ', missing: const []);
      expect(text, contains('خادم الفصل'));
      expect(text, contains('بيانات'));
    });
  });

  group('a child in the list', () {
    Widget app(Child c) => MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: MissingInfoTile(
                child: c,
                servantName: 'أبانوب',
                onTap: () {},
              ),
            ),
          ),
        );

    testWidgets('shows the name and what is missing, the birthday too',
        (tester) async {
      await tester.pumpWidget(app(_full(noBirth: true, school: null)));
      await tester.pumpAndSettle();

      expect(find.text('مينا'), findsOneWidget);
      expect(find.text('تاريخ الميلاد'), findsOneWidget);
      expect(find.text('المدرسة'), findsOneWidget);
      expect(find.text('العنوان'), findsNothing); // not missing
    });

    testWidgets('offers WhatsApp when somebody can be written to',
        (tester) async {
      await tester.pumpWidget(app(_full(noBirth: true)));
      await tester.pumpAndSettle();
      expect(find.byType(WhatsAppIcon), findsOneWidget);
    });

    testWidgets('no WhatsApp when there is no number at all', (tester) async {
      await tester.pumpWidget(app(_full(
        noBirth: true,
        mobile: null,
        motherMobile: null,
        fatherMobile: null,
      )));
      await tester.pumpAndSettle();
      expect(find.byType(WhatsAppIcon), findsNothing);
      expect(find.text('رقم تليفون'), findsOneWidget);
    });

    testWidgets('a tap opens the child', (tester) async {
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MissingInfoTile(
            child: _full(noBirth: true),
            servantName: 'أبانوب',
            onTap: () => opened++,
          ),
        ),
      ));
      await tester.tap(find.text('مينا'));
      expect(opened, 1);
    });
  });
}
