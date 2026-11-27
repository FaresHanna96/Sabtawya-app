// The website as an installed app: updates, install, shortcuts, shared files,
// keeping the screen on and the screen lock.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/services/push_service.dart';
import 'package:sabtawya/core/services/update_service.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/core/widgets/keep_awake.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/features/home/home_shell.dart';
import 'package:sabtawya/features/home/launch_actions.dart';
import 'package:sabtawya/features/home/more_entries.dart';
import 'package:sabtawya/features/home/web_cards.dart';
import 'package:sabtawya/features/lock/app_lock.dart';
import 'package:sabtawya/features/servant_activities/shared_files_sheet.dart';
import 'package:sabtawya/features/settings/web_app_tiles.dart';
import 'package:sabtawya/state/session_controller.dart';

class _Session extends ChangeNotifier implements SessionController {
  SessionStatus _status = SessionStatus.loading;
  int signedOut = 0;

  @override
  SessionStatus get status => _status;

  void go(SessionStatus s) {
    _status = s;
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    signedOut++;
    go(SessionStatus.signedOut);
  }

  @override
  String get displayName => 'خادم';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LockStore implements AppLockStore {
  _LockStore([this.id]);
  String? id;
  @override
  Future<String?> passkey() async => id;
  @override
  Future<void> save(String value) async => id = value;
  @override
  Future<void> clear() async => id = null;
}

class _InstallStore implements InstallCardStore {
  bool isClosed = false;
  @override
  Future<bool> closed() async => isClosed;
  @override
  Future<void> close() async => isClosed = true;
}

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('updates on the website', () {
    final client = MockClient((_) async => http.Response(
        jsonEncode({'version': '9.0.0', 'build': 900, 'min_build': 900}), 200));

    test('the quiet check finds a newer build, and that it is forced',
        () async {
      final found =
          await UpdateService.check(client: client, web: true, current: 1);
      expect(found!.build, 900);
      expect(found.forced, isTrue);
      expect(
          await UpdateService.check(client: client, web: true, current: 900),
          isNull);
    });

    const update = AppUpdate(version: '9.0.0', build: 900, forced: true);

    testWidgets('a forced one reloads once by itself, then waits for the tap',
        (tester) async {
      var reloads = 0;
      var first = true;
      Widget screen() => MaterialApp(
            home: ForcedUpdateScreen(
              key: UniqueKey(),
              update: update,
              web: true,
              reload: () async => reloads++,
              firstReload: (_) {
                final was = first;
                first = false;
                return was;
              },
            ),
          );
      await tester.pumpWidget(screen());
      expect(reloads, 1);
      await tester.pumpWidget(screen());
      expect(reloads, 1);
      expect(find.text(AppStrings.updateManual), findsNothing);
      await tester.tap(find.text(AppStrings.updateReload));
      expect(reloads, 2);
    });
  });

  group('installing', () {
    test('a closed card comes back after two weeks', () {
      final closed = DateTime(2026, 11, 1);
      bool at(int days) => InstallCardStore.stillClosed(
          closed.toIso8601String(), closed.add(Duration(days: days)));
      expect(at(13), isTrue);
      expect(at(14), isFalse);
      // What the older version kept had no time: shown again.
      expect(InstallCardStore.stillClosed(true, closed), isFalse);
      expect(InstallCardStore.stillClosed(null, closed), isFalse);
    });

    testWidgets('where the browser can install, the card offers it',
        (tester) async {
      var installs = 0;
      final store = _InstallStore();
      await tester.pumpWidget(_app(WebCards(
        web: true,
        ios: false,
        installed: false,
        store: store,
        canInstall: ValueNotifier(true),
        install: () async {
          installs++;
          return true;
        },
        permission: ValueNotifier(PushPermission.notAsked),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.installAction));
      expect(installs, 1);
      // Closing it brings the notifications card instead.
      await tester.tap(find.byTooltip(AppStrings.close));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.installAction), findsNothing);
      expect(find.text(AppStrings.enableNotifications), findsWidgets);
      expect(store.isClosed, isTrue);
    });

    testWidgets('the settings row explains the steps when it cannot ask',
        (tester) async {
      await tester.pumpWidget(_app(InstallTile(
          web: true,
          ios: true,
          installed: false,
          available: ValueNotifier(false))));
      await tester.tap(find.text(AppStrings.installRow));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.installSteps), findsOneWidget);
    });

    testWidgets('no row once installed', (tester) async {
      await tester
          .pumpWidget(_app(const InstallTile(web: true, installed: true)));
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('icon shortcuts', () {
    test('attendance is a tab; the others are pages the role has', () {
      expect(launchTarget('attendance', MoreRole.servant), isA<LaunchTab>());
      expect(launchTarget('birthdays', MoreRole.servant), isA<LaunchPage>());
      expect(launchTarget('absence', MoreRole.admin), isA<LaunchPage>());
      expect(launchTarget('preps', MoreRole.admin), isNull);
      expect(launchTarget(null, MoreRole.admin), isNull);
    });

    test('the manifest offers them, and receives shared files', () {
      final m = jsonDecode(File('web/manifest.json')
          .readAsStringSync()
          .replaceFirst('\u{feff}', '')) as Map<String, dynamic>;
      expect([for (final s in m['shortcuts'] as List) s['url']], [
        './?go=attendance',
        './?go=absence',
        './?go=birthdays',
      ]);
      expect(m['share_target']['action'], '/share-target');
      expect(File('web/app-sw.js').readAsStringSync(),
          contains("url.pathname === '/share-target'"));
      expect(m['short_name'], 'سبتاوية');
      for (final shot in m['screenshots'] as List) {
        expect(File('web/${shot['src']}').existsSync(), isTrue);
      }
    });

    test('the page loads the browser features before the app', () {
      final page = File('web/index.html').readAsStringSync();
      expect(page.indexOf('src="pwa.js"'), isPositive);
      expect(page.indexOf('src="pwa.js"'),
          lessThan(page.indexOf('src="flutter_bootstrap.js"')));
      expect(page, contains('app-retry'));
    });
  });

  test('shared files go to the coming Saturday first, one line a date', () {
    AttendanceSession s(String id, DateTime d) => AttendanceSession(
        id: id, yearId: 'y', classId: 'c', sessionDate: d, isLocked: false);
    final dates = sharedFileDates([
      s('old', DateTime(2026, 10, 1)),
      s('last', DateTime(2026, 11, 21)),
      s('next', DateTime(2026, 11, 28)),
      s('twin', DateTime(2026, 11, 28)),
      s('after', DateTime(2026, 12, 5)),
      s('far', DateTime(2027, 2, 6)),
    ], now: DateTime(2026, 11, 27));
    expect([for (final d in dates) d.id], ['next', 'after', 'last']);
  });

  testWidgets('the screen is kept on only while the page is shown',
      (tester) async {
    final calls = <bool>[];
    Widget page(bool shown) => TickerMode(
        enabled: shown,
        child: KeepAwake(apply: calls.add, child: const SizedBox()));
    await tester.pumpWidget(page(true));
    await tester.pumpWidget(page(false));
    await tester.pumpWidget(page(true));
    await tester.pumpWidget(const SizedBox());
    expect(calls, [true, false, true, false]);
  });

  group('the screen lock', () {
    late _Session session;
    late DateTime now;
    var allow = true;

    Widget gate(_LockStore store) =>
        ChangeNotifierProvider<SessionController>.value(
          value: session,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: AppLockGate(
              web: true,
              store: store,
              now: () => now,
              check: (_) async => allow,
              child: const Text('inside'),
            ),
          ),
        );

    setUp(() {
      session = _Session();
      now = DateTime(2026, 11, 28, 10);
      allow = true;
    });

    Future<void> away(WidgetTester tester, Duration time) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      now = now.add(time);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('opens locked, and stays so until the passkey agrees',
        (tester) async {
      await tester.pumpWidget(gate(_LockStore('k')));
      session.go(SessionStatus.ready);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.appLockedTitle), findsOneWidget);
      allow = false;
      await tester.tap(find.text(AppStrings.appLockOpen));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.appLockFailed), findsOneWidget);
      allow = true;
      await tester.tap(find.text(AppStrings.appLockOpen));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.appLockedTitle), findsNothing);
      expect(find.text('inside'), findsOneWidget);
    });

    testWidgets('locks again after five minutes away, not sooner',
        (tester) async {
      await tester.pumpWidget(gate(_LockStore('k')));
      session.go(SessionStatus.ready);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.appLockOpen));
      await tester.pumpAndSettle();
      await away(tester, const Duration(minutes: 4));
      expect(find.text(AppStrings.appLockedTitle), findsNothing);
      await away(tester, const Duration(minutes: 5));
      expect(find.text(AppStrings.appLockedTitle), findsOneWidget);
    });

    testWidgets('signing out is always a way back', (tester) async {
      await tester.pumpWidget(gate(_LockStore('k')));
      session.go(SessionStatus.ready);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.logout));
      await tester.pumpAndSettle();
      expect(session.signedOut, 1);
      expect(find.text(AppStrings.appLockedTitle), findsNothing);
    });

    testWidgets('nothing shows, lock screen included, while it is being read',
        (tester) async {
      await tester.pumpWidget(gate(_LockStore()));
      session.go(SessionStatus.ready);
      await tester.pump(Duration.zero, EnginePhase.build);
      expect(find.text(AppStrings.appLockedTitle), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('inside'), findsOneWidget);
    });

    testWidgets('off by default, and not asked right after signing in',
        (tester) async {
      await tester.pumpWidget(gate(_LockStore()));
      session.go(SessionStatus.ready);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.appLockedTitle), findsNothing);

      session = _Session();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(gate(_LockStore('k')));
      session.go(SessionStatus.signedOut);
      await tester.pumpAndSettle();
      session.go(SessionStatus.ready);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.appLockedTitle), findsNothing);
    });

    testWidgets('the switch turns it on, and off only with the passkey',
        (tester) async {
      final store = _LockStore();
      await tester.pumpWidget(ChangeNotifierProvider<SessionController>.value(
        value: session,
        child: _app(AppLockTile(
          web: true,
          store: store,
          supported: () async => true,
          create: (_) async => 'new',
          check: (_) async => allow,
        )),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(store.id, 'new');
      allow = false;
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(store.id, 'new');
      allow = true;
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(store.id, isNull);
    });
  });
}
