import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';
import 'package:sabtawya/core/services/update_service.dart';
import 'package:sabtawya/data/services/access_log.dart';
import 'package:sabtawya/features/home/home_shell.dart';

void main() {
  const update = AppUpdate(
    version: '9.9.9',
    build: 999,
    forced: true,
    apkUrl: 'https://x/a.apk',
    sha256:
        '0000000000000000000000000000000000000000000000000000000000000000',
  );

  late int logged;
  setUp(() {
    logged = 0;
    AccessLog.debugResetUpdateLogged();
    AccessLog.debugOnUpdateDownload = () => logged++;
  });
  tearDown(() {
    AccessLog.debugOnUpdateDownload = null;
    debugOtaStarter = null;
  });

  Future<StreamController<OtaEvent>> open(WidgetTester tester) async {
    final c = StreamController<OtaEvent>(sync: true);
    debugOtaStarter = (_) => c.stream;
    await tester.pumpWidget(const MaterialApp(
      home: ForcedUpdateScreen(update: update),
    ));
    await tester.pump(); // the download starts by itself
    return c;
  }

  testWidgets('one download is logged when the app starts downloading, once',
      (tester) async {
    final c = await open(tester);
    expect(logged, 0); // asked to start, nothing downloaded yet
    c.add(OtaEvent(OtaStatus.DOWNLOADING, '5'));
    await tester.pump();
    c.add(OtaEvent(OtaStatus.DOWNLOADING, '60'));
    await tester.pump();
    expect(logged, 1);
    // A failure and a retry in the same run are the same person.
    c.add(OtaEvent(OtaStatus.DOWNLOAD_ERROR, ''));
    await tester.pump();
    c.add(OtaEvent(OtaStatus.DOWNLOADING, '10'));
    await tester.pump();
    expect(logged, 1);
  });

  testWidgets('no download, nothing logged (permission refused)',
      (tester) async {
    final c = await open(tester);
    c.add(OtaEvent(OtaStatus.PERMISSION_NOT_GRANTED_ERROR, ''));
    await tester.pump();
    expect(logged, 0);
  });

  test('an update is told apart from a page download', () {
    expect(AccessLog.updatePlatform, 'update');
  });
}
