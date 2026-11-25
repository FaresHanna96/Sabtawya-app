import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/features/home/more_screen.dart';

void main() {
  test('the avatar letter is the first name\'s first letter', () {
    expect(profileAvatarLetter('أمين خدمة تجريبي'), 'أ');
    expect(profileAvatarLetter('  مينا فايز'), 'م');
    expect(profileAvatarLetter(''), '؟');
  });
}
