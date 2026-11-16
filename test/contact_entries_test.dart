import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/contact_entries.dart';
import 'package:sabtawya/data/models/child.dart';

Child kid(String id, String name,
        {String cls = 'c1',
        String? mother,
        String? father,
        String? own,
        bool active = true}) =>
    Child(
      id: id,
      classId: cls,
      fullName: name,
      gender: Gender.boy,
      isActive: active,
      motherMobile: mother,
      fatherMobile: father,
      mobile: own,
    );

const classes = {'c1': 'فصل 5 بنات'};

void main() {
  test('dial numbers: Egyptian mobiles get +20, others keep their digits', () {
    expect(dialNumber('01012345678'), '+201012345678');
    expect(dialNumber('+20 101 234 5678'), '+201012345678');
    expect(dialNumber('٠١٠١٢٣٤٥٦٧٨'), '+201012345678');
    expect(dialNumber('0224112233'), '0224112233'); // a landline
    expect(dialNumber('123'), isNull);
    expect(dialNumber(null), isNull);
  });

  test('numbers match by their last ten digits', () {
    expect(numberKey('+201012345678'), numberKey('01012345678'));
    expect(numberKey('00201012345678'), numberKey('1012345678'));
    expect(numberKey('01012345678'), isNot(numberKey('01112345678')));
  });

  test('names say whose family and class; nobody without a number', () {
    final e = contactEntriesFor([
      kid('1', 'مينا جورج', mother: '01012345678', father: '01112345678'),
      kid('2', 'بدون أرقام'),
    ], classes);
    expect(e.map((x) => x.label),
        ['أم مينا جورج – فصل 5 بنات', 'أب مينا جورج – فصل 5 بنات']);
    expect(e.first.number, '+201012345678');
  });

  test('choosing who to include, and inactive children are skipped', () {
    final all = [
      kid('1', 'مينا', mother: '01012345678', father: '01112345678',
          own: '01212345678'),
      kid('2', 'مريم', mother: '01512345678', active: false),
    ];
    expect(contactEntriesFor(all, classes).length, 3);
    expect(
        contactEntriesFor(all, classes, father: false, child: false)
            .map((x) => x.label),
        ['أم مينا – فصل 5 بنات']);
  });

  test('a shared number is one entry named after both children', () {
    final e = contactEntriesFor([
      kid('1', 'مينا', mother: '01012345678'),
      kid('2', 'مريم', mother: '+201012345678'),
    ], classes);
    expect(e, hasLength(1));
    expect(e.single.label, 'أم مينا – فصل 5 بنات / أم مريم – فصل 5 بنات');
  });

  test('one contact per child with father, mother and child numbers', () {
    final cards = contactCardsFor([
      kid('1', 'مينا جورج',
          mother: '01012345678', father: '01112345678', own: '01212345678'),
      kid('2', 'بدون أرقام'),
      kid('3', 'مريم', mother: '01512345678', active: false),
    ], classes);
    expect(cards, hasLength(1));
    expect(cards.single.name, 'مينا جورج – فصل 5 بنات');
    expect(cards.single.phones.map((p) => p.label),
        ['الأب', 'الأم', 'المخدوم']);
    expect(cards.single.phones.first.number, '+201112345678');
  });

  test('cards: choose who, and a repeated number is kept once', () {
    final kids = [
      kid('1', 'مينا', mother: '01012345678', father: '01112345678',
          own: '+201012345678'),
    ];
    expect(contactCardsFor(kids, classes).single.phones, hasLength(2));
    expect(
        contactCardsFor(kids, classes, father: false, child: false)
            .single
            .phones
            .map((p) => p.label),
        ['الأم']);
    expect(
        contactCardsFor(kids, classes,
            mother: false, father: false, child: false),
        isEmpty);
  });

  test('siblings sharing a mother each get a card with her number', () {
    final cards = contactCardsFor([
      kid('1', 'مينا', mother: '01012345678'),
      kid('2', 'مريم', mother: '01012345678'),
    ], classes);
    expect(cards, hasLength(2));
  });

  test('vCard: one card per child, labelled numbers, UTF-8, escaped, CRLF', () {
    const eol = '\r\n';
    final v = buildVCards([
      const ContactCard('مينا, جورج; س', [
        (label: 'الأب', number: '+201112345678'),
        (label: 'الأم', number: '+201012345678'),
      ]),
    ]);
    expect(v, startsWith('BEGIN:VCARD${eol}VERSION:3.0$eol'));
    expect(v, contains(r'FN;CHARSET=UTF-8:مينا\, جورج\; س'));
    expect(v, contains('item1.TEL;TYPE=CELL:+201112345678$eol'));
    expect(v, contains('item1.X-ABLabel;CHARSET=UTF-8:الأب$eol'));
    expect(v, contains('item2.TEL;TYPE=CELL:+201012345678$eol'));
    expect(v, contains('item2.X-ABLabel;CHARSET=UTF-8:الأم$eol'));
    expect(v, endsWith('END:VCARD$eol'));
    expect(buildVCards([]), isEmpty);
  });
}
