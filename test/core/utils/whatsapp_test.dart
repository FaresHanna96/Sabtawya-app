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
    test('the mother first, then the father, then the child', () {
      expect(
        WhatsApp.numberFor(_child(
            mobile: '01011111111',
            mother: '01022222222',
            father: '01033333333')),
        '201022222222',
      );
      expect(
        WhatsApp.numberFor(
            _child(mobile: '01011111111', father: '01033333333')),
        '201033333333',
      );
      expect(WhatsApp.numberFor(_child(mobile: '01011111111')), '201011111111');
    });

    test('a number that cannot be used is skipped, not given up on', () {
      expect(
        WhatsApp.numberFor(
            _child(mother: '0222222222', father: '01033333333', mobile: 'x')),
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

  test('the link carries the number and the encoded text', () {
    final uri = WhatsApp.link('201012345678', 'سلام ونعمة & شكرًا');
    expect(uri.scheme, 'https');
    expect(uri.host, 'wa.me');
    expect(uri.path, '/201012345678');
    expect(uri.queryParameters['text'], 'سلام ونعمة & شكرًا');
    expect(uri.toString().contains(' '), isFalse);
  });
}
