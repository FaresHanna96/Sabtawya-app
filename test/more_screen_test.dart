import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/features/home/more_entries.dart';
import 'package:sabtawya/features/home/more_screen.dart';

Future<List<MoreEntry>> _pump(
  WidgetTester tester, {
  MoreRole role = MoreRole.admin,
  Map<MoreCount, int> counts = const {},
  VoidCallback? onWhatsNew,
}) async {
  final opened = <MoreEntry>[];
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: MoreView(
            role: role,
            name: 'مينا فايز',
            roleLabel: 'أمين الخدمة',
            subtitle: '2026 - 2027',
            counts: counts,
            version: AppStrings.versionLabel('1.0.50', 51),
            onOpen: opened.add,
            onWhatsNew: onWhatsNew,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
  return opened;
}

void main() {
  testWidgets('the page can always be pulled down to refresh', (tester) async {
    await _pump(tester);
    final list = tester.widget<ListView>(find.byType(ListView).first);
    expect(list.physics, isA<AlwaysScrollableScrollPhysics>());
  });

  testWidgets('the header shows the name, the first letter and role', (tester) async {
    await _pump(tester);
    expect(find.text('مينا فايز'), findsOneWidget);
    expect(find.text('م'), findsOneWidget);
    expect(find.text('أمين الخدمة'), findsOneWidget);
    expect(find.text('2026 - 2027'), findsOneWidget);
  });

  testWidgets('counts show as badges, and nothing at zero', (tester) async {
    await _pump(tester, counts: {
      MoreCount.absence: 7,
      MoreCount.missingInfo: 0,
      MoreCount.failedSync: 2,
    });
    expect(find.text('7'), findsOneWidget); // absence, in the grid
    expect(find.text('0'), findsNothing);
    await tester.scrollUntilVisible(
      find.text(AppStrings.syncTitle),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2'), findsOneWidget); // failed sync, on its row
    expect(find.text('0'), findsNothing);
  });

  testWidgets('a tile opens its entry', (tester) async {
    final opened = await _pump(tester);
    await tester.tap(find.text(AppStrings.absenceFollowUp));
    await tester.pump(const Duration(milliseconds: 300));
    expect(opened.single.id, 'absence');
  });

  testWidgets('typing hides the grid and lists the matches', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'اكسل');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppStrings.importChildren), findsOneWidget);
    expect(find.text(AppStrings.excelReportsTitle), findsOneWidget);
    expect(find.text(AppStrings.moreAdmin), findsNothing);
    expect(find.text(AppStrings.absenceFollowUp), findsNothing);

    await tester.enterText(find.byType(TextField), 'شيء مش موجود');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppStrings.moreNoMatches), findsOneWidget);
  });

  testWidgets('a class servant sees no admin card and no competitions',
      (tester) async {
    await _pump(tester, role: MoreRole.servant);
    await tester.scrollUntilVisible(
      find.text(AppStrings.settingsTitle),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(AppStrings.moreAdmin), findsNothing);
    expect(find.text(AppStrings.competitions), findsNothing);
    expect(find.text(AppStrings.importChildren), findsOneWidget);
  });

  testWidgets('the update check row is tappable', (tester) async {
    final opened = await _pump(tester);
    await tester.scrollUntilVisible(
      find.text(AppStrings.checkForUpdates),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Fully on screen, not just reached at the bottom edge.
    await tester.ensureVisible(find.text(AppStrings.checkForUpdates));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.checkForUpdates));
    await tester.pump(const Duration(milliseconds: 300));
    expect(opened.single.id, MoreCatalog.updatesId);
  });

  testWidgets('the footer shows the version and what is new', (tester) async {
    var asked = 0;
    await _pump(tester, onWhatsNew: () => asked++);
    await tester.scrollUntilVisible(
      find.text(AppStrings.whatsNewTitle),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('الإصدار 1.0.50 (51)'), findsOneWidget);
    await tester.tap(find.text(AppStrings.whatsNewTitle));
    expect(asked, 1);
  });
}
