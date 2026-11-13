import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/config/app_version.dart';
import 'package:sabtawya/core/services/update_service.dart';

void main() {
  test('kAppVersion and kAppBuild match pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(line.trim(), 'version: $kAppVersion+$kAppBuild');
  });

  group('newerThanThis', () {
    test('a higher build is an update', () {
      final u = UpdateService.newerThanThis({'version': '1.0.3', 'build': 4},
          current: 3);
      expect(u?.version, '1.0.3');
    });
    test('same or lower build is not', () {
      expect(
          UpdateService.newerThanThis({'version': '1.0.2', 'build': 3},
              current: 3),
          isNull);
      expect(
          UpdateService.newerThanThis({'version': '1.0.1', 'build': 2},
              current: 3),
          isNull);
    });
    test("this phone's APK and fingerprint are picked", () {
      final json = {
        'version': '1.0.4',
        'build': 9,
        'apk': {
          'arm64': {'url': 'https://x/a64.apk', 'sha256': 'A' * 64},
          'armv7': {'url': 'https://x/a32.apk', 'sha256': 'b' * 64},
        },
      };
      final u64 = UpdateService.newerThanThis(json, current: 3, abi: 'arm64')!;
      expect(u64.apkUrl, 'https://x/a64.apk');
      expect(u64.sha256, 'a' * 64);
      expect(u64.canInstallInApp, isTrue);
      final u32 = UpdateService.newerThanThis(json, current: 3, abi: 'armv7')!;
      expect(u32.apkUrl, 'https://x/a32.apk');
    });

    test('without APK details it falls back to the download page', () {
      final u = UpdateService.newerThanThis({'version': '1.0.4', 'build': 9},
          current: 3)!;
      expect(u.canInstallInApp, isFalse);
    });

    test('the phone type comes from Platform.version', () {
      expect(
          UpdateService.deviceAbi('3.9 (stable) on "android_arm64"'), 'arm64');
      expect(UpdateService.deviceAbi('3.9 (stable) on "android_arm"'), 'armv7');
      expect(UpdateService.deviceAbi('3.9 on "windows_x64"'), 'arm64');
    });

    test('anything malformed is ignored', () {
      expect(UpdateService.newerThanThis(null), isNull);
      expect(UpdateService.newerThanThis({'build': '4'}), isNull);
      expect(UpdateService.newerThanThis([1, 2]), isNull);
    });
  });
}
