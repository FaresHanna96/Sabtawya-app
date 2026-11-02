import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/profile.dart';

void main() {
  group('ServantDetails.fromMap', () {
    test('reads every field and treats blanks as missing', () {
      final d = ServantDetails.fromMap(<String, dynamic>{
        'profile_id': 'p1',
        'address': ' ١٠ ش ابو العتاهية ',
        'confessor': 'ابونا لوقا',
        'occupation': '',
      });

      expect(d.profileId, 'p1');
      expect(d.address, isNotNull);
      expect(d.confessor, 'ابونا لوقا');
      expect(d.occupation, isNull);
      expect(d.isEmpty, isFalse);
    });

    test('a row with nothing filled in is empty', () {
      final d = ServantDetails.fromMap(<String, dynamic>{'profile_id': 'p2'});
      expect(d.isEmpty, isTrue);
    });
  });
}
