import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/features/dashboard/next_saturday_prep_card.dart';

Future<void> _pump(WidgetTester t, Widget card, {double width = 300}) =>
    t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Center(child: SizedBox(width: width, child: card)),
          ),
        ),
      ),
    ));

const _classes = [
  (id: 'a', name: 'هاتور'),
  (id: 'b', name: 'كيهك'),
  (id: 'c', name: 'طوبة'),
];

void main() {
  group('PrepProgress', () {
    testWidgets('a tick for a class that sent, «لسه» for one that did not',
        (t) async {
      await _pump(
          t, const PrepProgress(classes: _classes, prepared: {'a'}));
      expect(find.text('هاتور'), findsOneWidget);
      expect(find.text('كيهك · ${AppStrings.prepNotYet}'), findsOneWidget);
      expect(find.text(AppStrings.prepDoneOf(1, 3)), findsOneWidget);
    });

    testWidgets('many classes: a bar and one line, the classes on a tap',
        (t) async {
      final many = [for (var i = 0; i < 8; i++) (id: '$i', name: 'فصل $i')];
      await _pump(t, PrepProgress(classes: many, prepared: const {}));
      expect(find.text(AppStrings.prepDoneOf(0, 8)), findsOneWidget);
      expect(find.textContaining(AppStrings.prepNotYet), findsNothing);
      await t.tap(find.text(AppStrings.prepProgressTitle));
      await t.pumpAndSettle();
      expect(find.textContaining(AppStrings.prepNotYet), findsNWidgets(8));
      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('all sent: the chip says so in green', (t) async {
      await _pump(
          t, const PrepProgress(classes: _classes, prepared: {'a', 'b', 'c'}));
      expect(find.text(AppStrings.prepDoneOf(3, 3)), findsOneWidget);
      expect(find.byIcon(Icons.fact_check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pending_actions_rounded), findsNothing);
    });

    testWidgets('fits a narrow phone', (t) async {
      final many = [for (var i = 0; i < 8; i++) (id: '$i', name: 'فصل رقم $i')];
      await _pump(t, PrepProgress(classes: many, prepared: const {'1'}),
          width: 230);
      await t.tap(find.text(AppStrings.prepProgressTitle));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('NextSaturdayCard', () {
    testWidgets('the date once, the lesson open at first, the prep count',
        (t) async {
      await _pump(
        t,
        const NextSaturdayCard(
          dateLabel: 'السبت، 28 نوفمبر • هاتور',
          lesson: Text('درس الأولاد'),
          hasLesson: true,
          lessonCount: 4,
          classes: _classes,
          prepared: {'a'},
        ),
      );
      expect(find.text(AppStrings.nextSaturdayCard), findsOneWidget);
      expect(find.text('السبت، 28 نوفمبر • هاتور'), findsOneWidget);
      expect(find.text('درس الأولاد'), findsOneWidget);
      // The card's own header folds it: one header, no second row.
      expect(find.text(AppStrings.lessonOfWeek), findsNothing);
      await t.tap(find.text(AppStrings.nextSaturdayCard));
      await t.pumpAndSettle();
      expect(find.text('درس الأولاد'), findsNothing);
      expect(find.text(AppStrings.prepDoneOf(1, 3)), findsOneWidget);
    });

    testWidgets('no lesson that day: the short message shows as it is',
        (t) async {
      await _pump(
        t,
        const NextSaturdayCard(
          dateLabel: 'السبت',
          lesson: Text('الدرس اتلغى'),
          hasLesson: false,
        ),
      );
      expect(find.text('الدرس اتلغى'), findsOneWidget);
      expect(find.text(AppStrings.lessonOfWeek), findsNothing);
    });

    testWidgets('one lesson only: shown directly, nothing to fold', (t) async {
      await _pump(
        t,
        const NextSaturdayCard(
          dateLabel: 'السبت',
          lesson: Text('درس الصف الثالث'),
          hasLesson: true,
          lessonCount: 1,
          lessonOpen: false, // even asked to start folded: nothing to open
        ),
      );
      expect(find.text('درس الصف الثالث'), findsOneWidget);
      expect(find.text(AppStrings.lessonOfWeek), findsNothing);
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
      expect(find.byIcon(Icons.expand_less_rounded), findsNothing);
    });

    testWidgets('lessonOpen: false starts folded', (t) async {
      await _pump(
        t,
        const NextSaturdayCard(
          dateLabel: 'السبت',
          lesson: Text('درس'),
          hasLesson: true,
          lessonCount: 2,
          lessonOpen: false,
        ),
      );
      expect(find.text('درس'), findsNothing);
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    });

    testWidgets('nothing loaded and no classes: nothing drawn', (t) async {
      await _pump(t, const NextSaturdayCard(dateLabel: 'السبت'));
      expect(find.text(AppStrings.nextSaturdayCard), findsNothing);
    });
  });
}
