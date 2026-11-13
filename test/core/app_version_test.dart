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
      final u = UpdateService.newerThanThis(
          {'version': '1.0.3', 'build': 4}, current: 3);
      expect(u?.version, '1.0.3');
    });
    test('same or lower build is not', () {
      expect(UpdateService.newerThanThis({'version': '1.0.2', 'build': 3},
          current: 3), isNull);
      expect(UpdateService.newerThanThis({'version': '1.0.1', 'build': 2},
          current: 3), isNull);
    });
    test('anything malformed is ignored', () {
      expect(UpdateService.newerThanThis(null), isNull);
      expect(UpdateService.newerThanThis({'build': '4'}), isNull);
      expect(UpdateService.newerThanThis([1, 2]), isNull);
    });
  });
}
