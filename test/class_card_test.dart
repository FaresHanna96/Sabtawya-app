import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/class_health.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/data/models/school_class.dart';
import 'package:sabtawya/features/classes/classes_screen.dart';

ClassOverview _class({
  String id = 'c1',
  int boys = 0,
  int girls = 10,
  int servants = 2,
  bool active = true,
}) =>
    ClassOverview(
      classId: id,
      className: '6 بنات',
      sortOrder: 1,
      isActive: active,
      activeChildren: boys + girls,
      boysCount: boys,
      girlsCount: girls,
      servantsCount: servants,
    );

ClassHealth _health(String id, {int servants = 2}) => ClassHealth(
      classId: id,
      className: id,
      servantsCount: servants,
      activeChildren: 10,
      held: 4,
      taken: 4,
      takenLate: 0,
      prepExpected: 4,
      prepSubmitted: 4,
      prepAccepted: 4,
      absent2plus: 0,
      absentFollowed: 0,
      attendancePct: 80,
    );

ClassWeek _week(String id, {int present = 8, bool recorded = true}) =>
    ClassWeek(
      classId: id,
      present: present,
      children: 10,
      recorded: recorded,
    );

Future<void> _pump(
  WidgetTester tester,
  ClassOverview overview,
  ClassCardFacts facts, {
  VoidCallback? onRecord,
}) =>
    tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: ClassCard(
                overview: overview,
                accent: Colors.blue,
                saturday: DateTime(2026, 11, 21),
                facts: facts,
                onRecord: onRecord ?? () {},
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    ));

void main() {
  group('classCardFacts', () {
    test('joins the week, the health and the prep per class', () {
      final facts = classCardFacts(
        weeks: {'a': _week('a'), 'b': _week('b')},
        health: [_health('a')],
        prepClasses: {'a'},
        noLesson: false,
      );
      expect(facts['a']!.week!.present, 8);
      expect(facts['a']!.score, isNotNull);
      expect(facts['a']!.level, HealthLevel.green);
      expect(facts['a']!.prepSent, isTrue);
      expect(facts['b']!.prepSent, isFalse);
      expect(facts['b']!.score, isNull);
    });

    test('preps not readable: the prep line is unknown', () {
      final facts = classCardFacts(
        weeks: {'a': _week('a')},
        health: const [],
        prepClasses: null,
        noLesson: false,
      );
      expect(facts['a']!.prepSent, isNull);
    });

    test('a Saturday with no lesson expects no prep', () {
      final facts = classCardFacts(
        weeks: {'a': _week('a')},
        health: const [],
        prepClasses: const {},
        noLesson: true,
      );
      expect(facts['a']!.prepSent, isNull);
    });

    test('a class that did not meet has no prep line', () {
      final facts = classCardFacts(
        weeks: const {},
        health: [_health('a')],
        prepClasses: const {},
        noLesson: false,
      );
      expect(facts['a']!.week, isNull);
      expect(facts['a']!.prepSent, isNull);
    });
  });

  group('ClassCard', () {
    testWidgets('a girls class: no boys and girls pills', (tester) async {
      await _pump(tester, _class(), const ClassCardFacts());
      expect(find.text(AppStrings.boys), findsNothing);
      expect(find.text(AppStrings.girls), findsNothing);
      expect(find.text(AppStrings.pillChildren), findsOneWidget);
      expect(find.text(AppStrings.pillServants), findsOneWidget);
    });

    testWidgets('a mixed class shows boys and girls', (tester) async {
      await _pump(tester, _class(boys: 4, girls: 6), const ClassCardFacts());
      expect(find.text(AppStrings.boys), findsOneWidget);
      expect(find.text(AppStrings.girls), findsOneWidget);
    });

    testWidgets('no servant: «محتاج خادم» in place of the count',
        (tester) async {
      await _pump(tester, _class(servants: 0), const ClassCardFacts());
      expect(find.text(AppStrings.classNeedsServant), findsOneWidget);
      expect(find.text(AppStrings.pillServants), findsNothing);
    });

    testWidgets('the health score shows as a chip', (tester) async {
      await _pump(
        tester,
        _class(),
        const ClassCardFacts(score: 78, level: HealthLevel.amber),
      );
      expect(find.byType(HealthScoreChip), findsOneWidget);
      // Said in words, the number out of 100 beside it.
      expect(find.text(AppStrings.healthToFollow), findsOneWidget);
      expect(find.text('78/100'), findsOneWidget);
      expect(find.byIcon(HealthScoreChip.iconOf(HealthLevel.amber)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (level, words) in [
      (HealthLevel.green, AppStrings.healthGood),
      (HealthLevel.amber, AppStrings.healthToFollow),
      (HealthLevel.red, AppStrings.healthNeedsSupport),
    ]) {
      testWidgets('$level reads «$words» and fits the card', (tester) async {
        await _pump(
          tester,
          _class(),
          ClassCardFacts(score: 38, level: level),
        );
        expect(find.text(words), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('recorded: nothing more to say on the card', (tester) async {
      await _pump(
        tester,
        _class(),
        ClassCardFacts(week: _week('c1'), prepSent: true),
      );
      // No «اتسجّل حضور» wording: the numbers say it.
      expect(find.text(AppStrings.classRecordedOn('21 نوفمبر')), findsNothing);
      // The numbers are on the class page, not on the card.
      expect(find.text('8/10'), findsNothing);
      expect(find.text('80%'), findsNothing);
      expect(tester.takeException(), isNull);
      // The prep line is not on the card any more.
      expect(find.text(AppStrings.prepSentLine), findsNothing);
      expect(find.text(AppStrings.recordNow), findsNothing);
    });

    testWidgets('not recorded: the button, and no prep yet', (tester) async {
      var recorded = 0;
      await _pump(
        tester,
        _class(),
        ClassCardFacts(
          week: _week('c1', present: 0, recorded: false),
          prepSent: false,
        ),
        onRecord: () => recorded++,
      );
      expect(find.text(AppStrings.prepNotSent), findsNothing);
      await tester.tap(find.text(AppStrings.recordNow));
      expect(recorded, 1);
    });

    testWidgets('prep unknown: no prep line at all', (tester) async {
      await _pump(tester, _class(), ClassCardFacts(week: _week('c1')));
      expect(find.text(AppStrings.prepSentLine), findsNothing);
      expect(find.text(AppStrings.prepNotSent), findsNothing);
    });

    testWidgets('an archived class shows no health chip', (tester) async {
      await _pump(
        tester,
        _class(active: false),
        const ClassCardFacts(score: 40, level: HealthLevel.red),
      );
      expect(find.byType(HealthScoreChip), findsNothing);
    });
  });
}
