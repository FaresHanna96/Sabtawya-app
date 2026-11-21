import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/config/app_version.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/services/update_service.dart';
import 'package:sabtawya/features/home/update_check.dart';

const _newer = AppUpdate(version: '9.9.9', build: 999);

class _Run {
  final found = <AppUpdate>[];
  var reloads = 0;
}

Future<_Run> _check(
  WidgetTester tester,
  UpdateCheck result, {
  bool web = false,
}) async {
  final run = _Run();
  await tester.pumpWidget(MaterialApp(
    // As in the app: Ui's snackbars float.
    theme: ThemeData(
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    ),
    home: Scaffold(
      body: Builder(
        builder: (c) => TextButton(
          onPressed: () => checkForUpdatesNow(
            c,
            onFound: run.found.add,
            check: () async => result,
            reload: () async => run.reloads++,
            web: web,
          ),
          child: const Text('check'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('check'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return run;
}

void main() {
  testWidgets('up to date says so, with this version', (tester) async {
    final run = await _check(tester, const UpdateCheck.upToDate());
    expect(find.text(AppStrings.upToDate(kAppVersion)), findsOneWidget);
    expect(run.found, isEmpty);
  });

  testWidgets('a failed check says it failed, not "up to date"',
      (tester) async {
    await _check(tester, const UpdateCheck.failed());
    expect(find.text(AppStrings.updateCheckFailed), findsOneWidget);
    expect(find.text(AppStrings.upToDate(kAppVersion)), findsNothing);
  });

  testWidgets('on a phone a newer build goes to the shell banner',
      (tester) async {
    final run = await _check(tester, const UpdateCheck.available(_newer));
    expect(run.found.single.build, 999);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('on the website a newer build offers a reload', (tester) async {
    final run =
        await _check(tester, const UpdateCheck.available(_newer), web: true);
    expect(find.text(AppStrings.updateAvailable('9.9.9')), findsOneWidget);
    await tester.tap(find.text(AppStrings.updateReload));
    await tester.pump(const Duration(milliseconds: 400));
    expect(run.reloads, 1);
    expect(run.found, isEmpty);
  });

  testWidgets('cancelling the reload keeps the page', (tester) async {
    final run =
        await _check(tester, const UpdateCheck.available(_newer), web: true);
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pump(const Duration(milliseconds: 400));
    expect(run.reloads, 0);
  });
}
