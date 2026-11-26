import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/services/push_service.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/features/home/web_cards.dart';
import 'package:sabtawya/features/settings/notifications_tile.dart';

class _Store implements InstallCardStore {
  _Store([this.isClosed = false]);

  bool isClosed;

  @override
  Future<bool> closed() async => isClosed;

  @override
  Future<void> close() async => isClosed = true;
}

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Column(children: [child])),
      ),
    );

void main() {
  group('an iPhone in a Safari tab', () {
    testWidgets('is told how to add the app, not offered notifications',
        (tester) async {
      await tester.pumpWidget(_app(WebCards(
        web: true,
        ios: true,
        installed: false,
        store: _Store(),
        permission: ValueNotifier(PushPermission.notAsked),
      )));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.installTitle), findsOneWidget);
      expect(find.text(AppStrings.enableNotifications), findsNothing);
    });

    testWidgets('closing the card is remembered', (tester) async {
      final store = _Store();
      await tester.pumpWidget(_app(
          WebCards(web: true, ios: true, installed: false, store: store)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(AppStrings.close));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.installTitle), findsNothing);
      expect(store.isClosed, isTrue);
    });

    testWidgets('a closed card stays closed', (tester) async {
      await tester.pumpWidget(_app(WebCards(
          web: true, ios: true, installed: false, store: _Store(true))));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.installTitle), findsNothing);
    });
  });

  group('notifications on the website', () {
    testWidgets('the tap asks, and the card leaves once allowed',
        (tester) async {
      final permission = ValueNotifier(PushPermission.notAsked);
      var asked = 0;
      await tester.pumpWidget(_app(WebCards(
        web: true,
        ios: true,
        installed: true,
        permission: permission,
        enable: () async {
          asked++;
          permission.value = PushPermission.granted;
        },
      )));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.installTitle), findsNothing);
      expect(asked, 0);
      await tester.tap(
          find.widgetWithText(FilledButton, AppStrings.enableNotifications));
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(AppStrings.notificationsOn), findsOneWidget);
    });

    testWidgets('no card when allowed, refused or unsupported', (tester) async {
      for (final state in [
        PushPermission.granted,
        PushPermission.denied,
        PushPermission.unknown,
      ]) {
        await tester.pumpWidget(_app(WebCards(
          key: ValueKey(state),
          web: true,
          ios: false,
          installed: false,
          permission: ValueNotifier(state),
        )));
        await tester.pumpAndSettle();
        expect(find.byType(FilledButton), findsNothing, reason: '$state');
      }
    });

    testWidgets('the phone app shows neither card nor row', (tester) async {
      await tester.pumpWidget(_app(Column(children: [
        WebCards(
            web: false,
            permission: ValueNotifier(PushPermission.notAsked)),
        NotificationsTile(
            web: false,
            permission: ValueNotifier(PushPermission.notAsked)),
      ])));
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('the settings row asks only while not asked', (tester) async {
      final permission = ValueNotifier(PushPermission.notAsked);
      var asked = 0;
      await tester.pumpWidget(_app(NotificationsTile(
        web: true,
        permission: permission,
        enable: () async {
          asked++;
          permission.value = PushPermission.denied;
        },
      )));
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(find.text(AppStrings.notificationsDenied), findsWidgets);
      await tester.tap(find.byType(ListTile), warnIfMissed: false);
      expect(asked, 1);
    });
  });

  group('offline opening', () {
    String read(String path) => File(path).readAsStringSync();

    test('the page registers our worker, and not Flutter\'s', () {
      expect(read('web/index.html'), contains("register('app-sw.js')"));
      expect(read('web/flutter_bootstrap.js'),
          isNot(contains('serviceWorkerSettings')));
    });

    test('the worker never saves the update check or the downloads', () {
      final live = RegExp(r'(version\.json|\.apk|apk\.html|stats\.html)$');
      expect(read('web/app-sw.js'), contains(live.pattern));
      for (final path in [
        '/version.json',
        '/sabtawya.apk',
        '/apk.html',
        '/stats.html'
      ]) {
        expect(live.hasMatch(path), isTrue, reason: path);
      }
      expect(live.hasMatch('/main.dart.js'), isFalse);
    });

    test('both builds take the drawing engine from our site', () {
      for (final script in ['build_web.ps1', 'build_dev.ps1']) {
        expect(read(script), contains('--no-web-resources-cdn'));
      }
    });
  });
}
