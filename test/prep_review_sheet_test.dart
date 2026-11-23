import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/servant_activity.dart';
import 'package:sabtawya/features/servant_activities/prep_review_sheet.dart';

final _prep = LessonPrep(
  id: 'p1',
  servantId: 's1',
  servantName: 'مينا فايز',
  sessionId: 'x',
  sessionDate: DateTime(2026, 11, 14),
  status: 'pending',
  photos: const [],
  className: '3 ولاد',
);

class _Run {
  PrepReviewResult? result;
  final reviews = <(String, String?)>[];
}

Future<_Run> _open(
  WidgetTester tester, {
  String? position,
  bool canSkip = false,
  LessonPrep? prep,
}) async {
  final run = _Run();
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    ),
    home: Scaffold(
      body: Builder(
        builder: (c) => TextButton(
          onPressed: () async {
            run.result = await showPrepReviewSheet(
              c,
              prep: prep ?? _prep,
              onReview: (status, comment) async =>
                  run.reviews.add((status, comment)),
              position: position,
              canSkip: canSkip,
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return run;
}

void main() {
  testWidgets('shows who sent it, the class and the place in the run',
      (tester) async {
    await _open(tester, position: AppStrings.prepPosition(2, 7), canSkip: true);
    expect(find.text('مينا فايز'), findsOneWidget);
    expect(find.textContaining('3 ولاد'), findsOneWidget);
    expect(find.text('2 من 7'), findsOneWidget);
  });

  testWidgets('a commented prep shows the comment itself, and a fresh one none',
      (tester) async {
    await _open(
      tester,
      prep: LessonPrep(
        id: 'p2',
        servantId: 's1',
        servantName: 'مينا فايز',
        sessionId: 'x',
        sessionDate: DateTime(2026, 11, 14),
        status: 'commented',
        adminComment: 'زوّد صورة',
        photos: const [],
        className: '3 ولاد',
      ),
    );
    // The read-only box and the pre-filled field.
    expect(find.text('زوّد صورة'), findsNWidgets(2));
  });

  testWidgets('a prep without a comment shows no comment box', (tester) async {
    await _open(tester);
    expect(find.text('زوّد صورة'), findsNothing);
  });

  testWidgets('skip comes back skipped and reviews nothing', (tester) async {
    final run = await _open(tester, canSkip: true);
    await tester.tap(find.text(AppStrings.skip));
    await tester.pump(const Duration(milliseconds: 500));
    expect(run.result, PrepReviewResult.skipped);
    expect(run.reviews, isEmpty);
  });

  testWidgets('accept comes back reviewed and saves it', (tester) async {
    final run = await _open(tester, canSkip: true);
    await tester.tap(find.text(AppStrings.acceptPrep));
    await tester.pump(const Duration(milliseconds: 500));
    expect(run.result, PrepReviewResult.reviewed);
    expect(run.reviews, [('accepted', null)]);
  });

  testWidgets('a single prep (not a run) has no skip and no position',
      (tester) async {
    final run = await _open(tester);
    expect(find.text(AppStrings.skip), findsNothing);
    expect(find.textContaining(' من '), findsNothing);
    // Dragging the sheet away is "closed".
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 500));
    expect(run.result, PrepReviewResult.closed);
  });
}
