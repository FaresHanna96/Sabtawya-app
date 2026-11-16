import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
