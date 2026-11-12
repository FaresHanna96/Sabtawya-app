import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/profile.dart';

void main() {
  test('is_hidden is read, and missing means visible', () {
    final base = <String, dynamic>{
      'id': 'p1',
      'full_name': 'أدمن تجريبي',
      'role': 'admin',
      'is_active': true,
    };
    expect(Profile.fromMap(base).isHidden, isFalse);
    expect(Profile.fromMap({...base, 'is_hidden': true}).isHidden, isTrue);
    expect(Profile.fromMap({...base, 'is_hidden': false}).isHidden, isFalse);
  });
}
