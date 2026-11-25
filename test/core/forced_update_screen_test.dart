import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/services/update_service.dart';
import 'package:sabtawya/features/home/home_shell.dart';

void main() {
  testWidgets('forced update screen has an update button and no way out',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ForcedUpdateScreen(
        update: AppUpdate(version: '1.0.29', build: 30, forced: true),
      ),
    ));

    expect(find.text(AppStrings.updateRequiredTitle), findsOneWidget);
    expect(find.text(AppStrings.updateRequiredBody('1.0.29')), findsOneWidget);
    expect(find.text(AppStrings.updateNow), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    final pop = tester.widget<PopScope>(find.byType(PopScope));
    expect(pop.canPop, isFalse);
  });

  const installable = AppUpdate(
    version: '1.0.29',
    build: 30,
    forced: true,
    apkUrl: 'https://x/a.apk',
    sha256:
        '0000000000000000000000000000000000000000000000000000000000000000',
  );

  Future<StreamController<OtaEvent>> open(WidgetTester tester) async {
    final c = StreamController<OtaEvent>(sync: true);
    var starts = 0;
    debugOtaStarter = (_) {
      starts++;
      return c.stream;
    };
    addTearDown(() => debugOtaStarter = null);
    await tester.pumpWidget(const MaterialApp(
      home: ForcedUpdateScreen(update: installable),
    ));
    await tester.pump(); // the download starts by itself
    expect(starts, 1);
    return c;
  }

  testWidgets('the web page link is always there, whatever the state',
      (tester) async {
    final c = await open(tester);
    // Downloading, installer open, then a failure: the link never goes away.
    expect(find.text(AppStrings.updateManual), findsOneWidget);
    c.add(OtaEvent(OtaStatus.DOWNLOADING, '40'));
    await tester.pump();
    expect(find.text(AppStrings.updateManual), findsOneWidget);
    c.add(OtaEvent(OtaStatus.INSTALLING, ''));
    await tester.pump();
    expect(find.text(AppStrings.updateInstalling), findsOneWidget);
    expect(find.text(AppStrings.updateManual), findsOneWidget);
    c.add(OtaEvent(OtaStatus.DOWNLOAD_ERROR, ''));
    await tester.pump();
    expect(find.text(AppStrings.updateManual), findsOneWidget);
  });

  testWidgets('a cancelled installer offers a retry after a while',
      (tester) async {
    final c = await open(tester);
    c.add(OtaEvent(OtaStatus.INSTALLING, ''));
    await tester.pump();
    expect(find.text(AppStrings.updateInstalling), findsOneWidget);
    expect(find.text(AppStrings.updateNow), findsNothing);

    await tester.pump(const Duration(seconds: 46));
    expect(find.text(AppStrings.updateNotFinished), findsOneWidget);
    expect(find.text(AppStrings.updateNow), findsOneWidget);
  });

  testWidgets('missing permission offers a retry, not only the web page',
      (tester) async {
    final c = await open(tester);
    c.add(OtaEvent(OtaStatus.PERMISSION_NOT_GRANTED_ERROR, ''));
    await tester.pump();
    expect(find.text(AppStrings.updateNeedsPermission), findsOneWidget);
    expect(find.text(AppStrings.updateNow), findsOneWidget);
    expect(find.text(AppStrings.updateOpenPage), findsNothing);
  });

  testWidgets('a download already running is not shown as a failure',
      (tester) async {
    final c = await open(tester);
    c.add(OtaEvent(OtaStatus.DOWNLOADING, '40'));
    await tester.pump();
    c.add(OtaEvent(OtaStatus.ALREADY_RUNNING_ERROR, ''));
    await tester.pump();
    expect(find.text(AppStrings.updateFailed), findsNothing);
    expect(find.text(AppStrings.updateDownloading(40)), findsOneWidget);
  });

  testWidgets('any other error still offers the web page', (tester) async {
    final c = await open(tester);
    c.add(OtaEvent(OtaStatus.DOWNLOAD_ERROR, ''));
    await tester.pump();
    expect(find.text(AppStrings.updateFailed), findsOneWidget);
    expect(find.text(AppStrings.updateOpenPage), findsOneWidget);
  });
}
