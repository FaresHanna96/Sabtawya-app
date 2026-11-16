import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/services/push_service.dart';

void main() {
  test('a Firebase installation id is told from a registration token', () {
    // 22 characters of base64url.
    expect(PushService.isInstallationId('cE3xK9_aB-1dQ7mZp0LwTg'), isTrue);
    expect(PushService.isInstallationId('A' * 22), isTrue);

    // A registration token: much longer, with a colon.
    expect(
      PushService.isInstallationId(
          'fKx3:APA91bHq7s0example-token-that-is-far-longer-than-an-id'),
      isFalse,
    );
    expect(PushService.isInstallationId('short'), isFalse);
    expect(PushService.isInstallationId('A' * 21), isFalse);
    expect(PushService.isInstallationId('A' * 23), isFalse);
    expect(PushService.isInstallationId('has a space in it xx'), isFalse);
    expect(PushService.isInstallationId(''), isFalse);
  });
}
