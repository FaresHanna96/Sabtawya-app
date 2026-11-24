import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/badges.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/models/profile.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/features/badges/champions_entry_screen.dart';
import 'package:sabtawya/features/badges/class_champions.dart';
import 'package:sabtawya/features/badges/class_order_screen.dart';
import 'package:sabtawya/features/children/child_tile.dart';
import 'package:sabtawya/features/classes/class_follow_up_strip.dart';
import 'package:sabtawya/features/classes/class_saturday_status.dart';
import 'package:sabtawya/features/classes/class_servants_card.dart';

Widget _rtl(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

ClassFollowUpStrip _strip({
  int absent = 0,
  int birthdays = 0,
  int missing = 0,
  List<String>? taps,
}) =>
    ClassFollowUpStrip(
      absent: absent,
      birthdays: birthdays,
      missing: missing,
      onAbsent: () => taps?.add('absent'),
      onBirthdays: () => taps?.add('birthdays'),
      onMissing: () => taps?.add('missing'),
    );

Child _child({bool active = true}) => Child(
      id: 'k1',
      classId: 'c',
      fullName: 'مينا جورج',
      gender: Gender.boy,
      isActive: active,
    );

ChildStreak _streak(String id, String name, int run,
        {String classId = 'c1', String className = '5 بنات'}) =>
    ChildStreak(
      childId: id,
      childName: name,
      classId: classId,
      className: className,
      absentStreak: 0,
      presentStreak: run,
    );

ClassServant _servant(String id, String name) => ClassServant(
      assignmentId: 'a$id',
      classId: 'c',
      className: '3 ولاد',
      servantId: id,
      servantName: name,
      servantIsActive: true,
    );

void main() {
  group('ClassFollowUpStrip', () {
    testWidgets('shows only the tiles with something to look at',
        (tester) async {
      await tester.pumpWidget(_rtl(_strip(absent: 3, birthdays: 2)));
      expect(find.text(AppStrings.classFollowUp), findsOneWidget);
      expect(find.text(AppStrings.followAbsent), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text(AppStrings.followBirthdays), findsOneWidget);
      expect(find.text(AppStrings.followMissing), findsNothing);
    });

    testWidgets('everything at zero shows nothing at all', (tester) async {
      await tester.pumpWidget(_rtl(_strip()));
      expect(find.text(AppStrings.classFollowUp), findsNothing);
      expect(_strip().isEmpty, isTrue);
    });

    testWidgets('each tile calls its own handler', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(_rtl(_strip(
        absent: 1,
        birthdays: 2,
        missing: 3,
        taps: taps,
      )));
      await tester.tap(find.text(AppStrings.followAbsent));
      await tester.tap(find.text(AppStrings.followBirthdays));
      await tester.tap(find.text(AppStrings.followMissing));
      expect(taps, ['absent', 'birthdays', 'missing']);
    });
  });

  group('ChildTile', () {
    testWidgets('«غاب N» from 2 Saturdays up', (tester) async {
      await tester.pumpWidget(_rtl(
          ChildTile(child: _child(), onTap: () {}, absentStreak: 3)));
      expect(find.text(AppStrings.absentFor(3)), findsOneWidget);
    });

    testWidgets('no pill for one missed Saturday or an inactive child',
        (tester) async {
      await tester.pumpWidget(_rtl(
          ChildTile(child: _child(), onTap: () {}, absentStreak: 1)));
      expect(find.textContaining('غاب'), findsNothing);
      await tester.pumpWidget(_rtl(ChildTile(
          child: _child(active: false), onTap: () {}, absentStreak: 4)));
      expect(find.textContaining('غاب'), findsNothing);
    });

    testWidgets('onContact puts the call button on the row', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_rtl(ChildTile(
        child: Child(
          id: 'k2',
          classId: 'c',
          fullName: 'مريم',
          gender: Gender.girl,
          isActive: true,
          mobile: '01012345678',
        ),
        onTap: () {},
        onContact: () => opened++,
      )));
      await tester.tap(find.byTooltip(AppStrings.call));
      expect(opened, 1);
    });
  });

  group('ClassServantsCard', () {
    testWidgets('your own row comes first', (tester) async {
      await tester.pumpWidget(_rtl(ClassServantsCard(
        servants: [_servant('1', 'ناهد'), _servant('2', 'مريم')],
        currentUserId: '2',
      )));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('مريم')).dy,
          lessThan(tester.getTopLeft(find.text('ناهد')).dy));
    });

    testWidgets('an empty class explains itself to a non-admin',
        (tester) async {
      await tester.pumpWidget(_rtl(const ClassServantsCard(servants: [])));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.noServantsHint), findsOneWidget);
    });
  });

  testWidgets('the attendance bar says what it is', (tester) async {
    await tester.pumpWidget(_rtl(SizedBox(
      width: 360,
      child: ClassSaturdayStatus(
        recorded: true,
        day: '21 نوفمبر',
        present: 7,
        children: 10,
        onRecord: () {},
      ),
    )));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(AppStrings.classWeekAttendance('21 نوفمبر')),
        findsOneWidget);
    expect(find.text('7/10'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
  });

  group('أبطال الالتزام', () {
    testWidgets('RunBadge: a flame and the run from 3 up, nothing below',
        (tester) async {
      await tester.pumpWidget(_rtl(const RunBadge(run: 4)));
      expect(find.text('4'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      await tester.pumpWidget(_rtl(const RunBadge(run: 2)));
      expect(find.text('2'), findsNothing);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
    });

    test('tiers and what is left for the next one', () {
      expect(ChampionTier.of(3).$1, AppStrings.committedTierNear);
      expect(ChampionTier.of(4).$1, AppStrings.tierCommitted);
      expect(ChampionTier.of(12).$1, AppStrings.tierGold);
      expect(ChampionTier.nextGoal(3), AppStrings.oneLeftForCommitted);
      expect(ChampionTier.nextGoal(11), AppStrings.leftForGold(1));
      expect(ChampionTier.nextGoal(12), isNull);
    });

    test('championsOf keeps runs of 3 or more, longest first', () {
      final list = ClassChampionsCard.championsOf([
        _streak('a', 'آدم', 3),
        _streak('b', 'باسم', 17),
        _streak('c', 'جورج', 5),
        _streak('d', 'داود', 2),
      ]);
      expect([for (final s in list) s.childName], ['باسم', 'جورج', 'آدم']);
    });

    test('equal runs: the one with more points comes first', () {
      final list = ClassChampionsCard.championsOf(
        [
          _streak('a', 'آدم', 5),
          _streak('b', 'باسم', 5),
          _streak('c', 'جورج', 6),
        ],
        points: const {'a': 60, 'b': 95, 'c': 10},
      );
      // The longest run wins whatever the points; then points break the tie.
      expect([for (final s in list) s.childName], ['جورج', 'باسم', 'آدم']);
    });

    testWidgets('the list shows the points of each child', (tester) async {
      await tester.pumpWidget(_rtl(SizedBox(
        height: 400,
        child: ChampionsView(
          streaks: [_streak('a', 'آدم', 5)],
          points: const {'a': 95},
        ),
      )));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(AppStrings.pointsOf(95)), findsOneWidget);
    });

    testWidgets('ChampionsView: longest run first, with its tier',
        (tester) async {
      await tester.pumpWidget(_rtl(SizedBox(
        height: 600,
        child: ChampionsView(streaks: [
          _streak('a', 'آدم', 3),
          _streak('b', 'باسم', 17),
          _streak('c', 'جورج', 5),
          _streak('d', 'داود', 2),
        ]),
      )));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('داود'), findsNothing, reason: 'run of 2 is not shown');
      expect(tester.getTopLeft(find.text('باسم')).dy,
          lessThan(tester.getTopLeft(find.text('جورج')).dy));
      expect(tester.getTopLeft(find.text('جورج')).dy,
          lessThan(tester.getTopLeft(find.text('آدم')).dy));
      expect(find.text(AppStrings.tierGold), findsOneWidget);
      expect(find.text(AppStrings.tierCommitted), findsOneWidget);
      expect(find.text(AppStrings.committedTierNear), findsOneWidget);
    });

    testWidgets('ChampionsView with nobody on a run says so', (tester) async {
      await tester.pumpWidget(_rtl(SizedBox(
        height: 400,
        child: ChampionsView(streaks: [_streak('a', 'آدم', 1)]),
      )));
      expect(find.text(AppStrings.noCommittedYet), findsOneWidget);
    });

    testWidgets('ClassChampionsCard: the first three and «عرض الكل»',
        (tester) async {
      var all = 0;
      await tester.pumpWidget(_rtl(ClassChampionsCard(
        champions: ClassChampionsCard.championsOf([
          _streak('a', 'آدم', 9),
          _streak('b', 'باسم', 8),
          _streak('c', 'جورج', 7),
          _streak('d', 'داود', 3),
        ]),
        onSeeAll: () => all++,
      )));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('آدم'), findsOneWidget);
      expect(find.text('جورج'), findsOneWidget);
      expect(find.text('داود'), findsNothing, reason: 'only the first three');
      await tester.tap(find.textContaining(AppStrings.seeAll));
      expect(all, 1);
    });

    testWidgets('the list over all classes names the class and filters',
        (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ChampionsEntryScreen(
            load: () async => ChampionsData(
              classes: const [],
              streaks: [
                _streak('a', 'آدم', 4),
                _streak('b', 'باسم', 6, classId: 'c2', className: '6 بنات'),
              ],
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(AppStrings.championsTitle), findsOneWidget);
      expect(find.textContaining('باسم'), findsOneWidget);
      expect(find.textContaining('آدم'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ClassOrderScreen', () {
    LeaderboardRow row(String id, String name, int points) => LeaderboardRow(
          childId: id,
          childName: name,
          attendancePoints: points,
          badgesEarned: 0,
          gamePoints: points,
        );

    testWidgets('the class by points, the opened child marked',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ClassOrderScreen(
            classId: 'c',
            className: '6 بنات',
            highlightChildId: 'b',
            load: () async => [
              row('a', 'آدم', 90),
              row('b', 'باسم', 70),
              row('c', 'جورج', 70),
            ],
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('آدم'), findsOneWidget);
      expect(find.text('باسم'), findsOneWidget);
      // Ties share a place: both 70s are 2nd.
      expect(find.text('2'), findsNWidgets(2));
      expect(find.text(AppStrings.rankingPointsNote), findsOneWidget);
    });

    testWidgets('nobody with points: the empty state', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ClassOrderScreen(
            classId: 'c',
            className: '6 بنات',
            load: () async => [row('a', 'آدم', 0)],
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(AppStrings.noRankingYet), findsOneWidget);
    });
  });
}
