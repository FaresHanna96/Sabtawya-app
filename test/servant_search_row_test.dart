import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/features/servant_activities/admin_servant_activities_screen.dart';

Future<void> _pump(WidgetTester tester, {VoidCallback? onMarkAll}) {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(MaterialApp(
    // The real theme: its filled buttons are full width by default, which
    // is what blanked this row.
    theme: AppTheme.light(),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ServantSearchRow(onChanged: (_) {}, onMarkAll: onMarkAll),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('lays out under the app theme: search and «الكل حضروا» show',
      (tester) async {
    var taps = 0;
    await _pump(tester, onMarkAll: () => taps++);
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.searchServantHint), findsOneWidget);
    expect(find.text(AppStrings.allServantsCame), findsOneWidget);
    await tester.tap(find.text(AppStrings.allServantsCame));
    expect(taps, 1);
    // The search box gets the rest of the width.
    final field = tester.getSize(find.byType(TextField));
    expect(field.width, greaterThan(100));
  });

  testWidgets('disabled when there is nothing to mark', (tester) async {
    await _pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.allServantsCame), findsOneWidget);
  });
}
