import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/whatsapp.dart';
import 'package:sabtawya/data/models/child.dart';

Child _child({String? mobile, String? mother, String? father}) => Child(
      id: 'c',
      classId: 'k',
      fullName: 'مينا',
      gender: Gender.boy,
      isActive: true,
      mobile: mobile,
      motherMobile: mother,
      fatherMobile: father,
    );

void main() {
  group('the number as WhatsApp wants it', () {
    test('Egyptian numbers however they were typed', () {
      const expected = '201012345678';
      for (final raw in [
        '01012345678',
        '010 1234 5678',
        '010-1234-5678',
        '+201012345678',
        '+20 10 1234 5678',
        '00201012345678',
        '201012345678',
        '1012345678', // the 0 lost in Excel
        ' 01012345678 ',
        '(010) 12345678',
      ]) {
        expect(WhatsApp.normalise(raw), expected, reason: raw);
      }
    });

    test('Arabic-Indic digits', () {
      expect(WhatsApp.normalise('٠١٠١٢٣٤٥٦٧٨'), '201012345678');
      expect(WhatsApp.normalise('+٢٠١٠١٢٣٤٥٦٧٨'), '201012345678');
    });

    test('other countries keep their code', () {
      expect(WhatsApp.normalise('+966501234567'), '966501234567');
      expect(WhatsApp.normalise('00966501234567'), '966501234567');
    });

    test('landlines, short and empty values are refused', () {
      expect(WhatsApp.normalise('0222222222'), isNull); // Cairo landline
      expect(WhatsApp.normalise('12345'), isNull);
      expect(WhatsApp.normalise('0101234'), isNull);
      expect(WhatsApp.normalise('+20101234567890123'), isNull);
      expect(WhatsApp.normalise(''), isNull);
      expect(WhatsApp.normalise('   '), isNull);
      expect(WhatsApp.normalise('لا يوجد'), isNull);
      expect(WhatsApp.normalise(null), isNull);
    });
  });

  group('which number is used', () {
    test('the child first, then the mother, then the father', () {
      expect(
        WhatsApp.numberFor(_child(
            mobile: '01011111111',
            mother: '01022222222',
            father: '01033333333')),
        '201011111111',
      );
      expect(
        WhatsApp.numberFor(
            _child(mother: '01022222222', father: '01033333333')),
        '201022222222',
      );
      expect(WhatsApp.numberFor(_child(father: '01033333333')), '201033333333');
    });

    test('a number that cannot be used is skipped, not given up on', () {
      expect(
        WhatsApp.numberFor(
            _child(mobile: 'x', mother: '0222222222', father: '01033333333')),
        '201033333333',
      );
    });

    test('nobody to write to', () {
      expect(WhatsApp.numberFor(_child()), isNull);
      expect(WhatsApp.numberFor(_child(mother: '', father: '12')), isNull);
      expect(WhatsApp.numberFor(null), isNull);
    });
  });

  group('the message', () {
    test('names the child and how long, in the servant\'s name', () {
      final one = WhatsApp.absenceMessage(
          childName: 'مينا عادل', servantName: 'أبانوب', absent: 1);
      expect(one, contains('أبانوب'));
      expect(one, contains('مينا عادل'));
      expect(one, contains('السبت اللي فات'));

      expect(
        WhatsApp.absenceMessage(childName: 'مينا', servantName: 'أ', absent: 2),
        contains('آخر سبتين'),
      );
      expect(
        WhatsApp.absenceMessage(childName: 'مينا', servantName: 'أ', absent: 5),
        contains('آخر 5 سبوت'),
      );
    });

    test('without a servant name it still reads well', () {
      final text = WhatsApp.absenceMessage(
          childName: 'مينا', servantName: '  ', absent: 3);
      expect(text, contains('خادم الفصل'));
    });
  });

  test('with no message the link is just the chat', () {
    final uri = WhatsApp.link('201012345678');
    expect(uri.toString(), 'https://wa.me/201012345678');
    expect(uri.hasQuery, isFalse);
  });

  test('the greeting names the servant and the child', () {
    final text =
        WhatsApp.greeting(childName: ' مينا عادل ', servantName: 'أبانوب');
    expect(text, contains('أبانوب'));
    expect(text, contains('مينا عادل'));
    expect(WhatsApp.greeting(childName: 'مينا', servantName: ' '),
        contains('خادم الفصل'));
  });

  test('the link carries the number and the encoded text', () {
    final uri = WhatsApp.link('201012345678', 'سلام ونعمة & شكرًا');
    expect(uri.scheme, 'https');
    expect(uri.host, 'wa.me');
    expect(uri.path, '/201012345678');
    expect(uri.queryParameters['text'], 'سلام ونعمة & شكرًا');
    expect(uri.toString().contains(' '), isFalse);
  });

  group('birthday greetings', () {
    test("go to the person's own number first", () {
      final t = WhatsApp.birthdayTarget(
        ownMobile: '01011111111',
        child: _child(mother: '01022222222'),
      );
      expect(t?.number, '201011111111');
      expect(t?.toThePerson, isTrue);
    });

    test('a child with no usable number of their own: mother, then father', () {
      final mother = WhatsApp.birthdayTarget(
        ownMobile: '',
        child: _child(mother: '01022222222', father: '01033333333'),
      );
      expect(mother?.number, '201022222222');
      expect(mother?.toThePerson, isFalse);

      final father = WhatsApp.birthdayTarget(
        ownMobile: '0222222222', // a landline
        child: _child(mother: 'x', father: '01033333333'),
      );
      expect(father?.number, '201033333333');
      expect(father?.toThePerson, isFalse);
    });

    test('a servant has no parent to fall back to', () {
      expect(WhatsApp.birthdayTarget(ownMobile: ''), isNull);
      expect(WhatsApp.birthdayTarget(ownMobile: '0222222222'), isNull);
    });

    test('nobody reachable', () {
      expect(WhatsApp.birthdayTarget(child: _child()), isNull);
    });

    test('the message to a boy and to a girl', () {
      final boy = WhatsApp.birthdayMessage(
          name: 'مينا عادل', servantName: 'أبانوب', toThePerson: true);
      expect(boy, contains('يا مينا'));
      expect(boy, contains('أبانوب'));
      expect(boy, contains('كل سنة وإنت طيب'));
      expect(boy, contains('عيد ميلادك'));

      final girl = WhatsApp.birthdayMessage(
          name: 'مريم سامي',
          servantName: 'أبانوب',
          toThePerson: true,
          girl: true);
      expect(girl, contains('كل سنة وإنتي طيبة'));
    });

    test('the message to a parent is about the child', () {
      final boy = WhatsApp.birthdayMessage(
          name: 'مينا عادل', servantName: 'أبانوب', toThePerson: false);
      expect(boy, contains('كل سنة ومينا طيب'));
      expect(boy, contains('ميلاده'));
      expect(boy, contains('ربنا يحفظه'));

      final girl = WhatsApp.birthdayMessage(
          name: 'مريم سامي',
          servantName: 'أبانوب',
          toThePerson: false,
          girl: true);
      expect(girl, contains('كل سنة ومريم طيبة'));
      expect(girl, contains('ميلادها'));
      expect(girl, contains('ربنا يحفظها'));
    });

    test('without a servant name it still reads well', () {
      expect(
        WhatsApp.birthdayMessage(
            name: 'مينا', servantName: ' ', toThePerson: true),
        contains('خادم الفصل'),
      );
    });
  });
}
