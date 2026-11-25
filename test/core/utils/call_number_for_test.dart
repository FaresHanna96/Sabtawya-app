import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/phone.dart';
import 'package:sabtawya/core/utils/whatsapp.dart';
import 'package:sabtawya/data/models/child.dart';

Child _c({String? mobile, String? mother, String? father}) => Child(
      id: 'k',
      classId: 'c',
      fullName: 'م',
      gender: Gender.girl,
      isActive: true,
      mobile: mobile,
      motherMobile: mother,
      fatherMobile: father,
    );

void main() {
  group('callNumberFor: the child, then the mother, then the father', () {
    test('every one has a number: the child\'s', () {
      expect(
        callNumberFor(_c(mobile: '0101', mother: '0102', father: '0103')),
        '0101',
      );
    });

    test('no number of their own: the mother\'s', () {
      expect(callNumberFor(_c(mother: '0102', father: '0103')), '0102');
    });

    test('only the father has one', () {
      expect(callNumberFor(_c(father: ' 0103 ')), '0103');
    });

    test('blank counts as none, and nobody gives null', () {
      expect(callNumberFor(_c(mobile: '  ', mother: '', father: null)), isNull);
      expect(callNumberFor(null), isNull);
    });
  });

  test('a call and a WhatsApp message reach the same person', () {
    final both = _c(mother: '01022222222', father: '01033333333');
    expect(callNumberFor(both), '01022222222');
    expect(WhatsApp.numberFor(both), '201022222222');
  });
}
