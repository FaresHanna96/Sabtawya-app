import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/badges.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/badges/badge_earned_dialog.dart';
import 'package:sabtawya/features/badges/badge_look.dart';
import 'package:sabtawya/features/badges/child_badges_card.dart';
import 'package:sabtawya/features/badges/class_leaderboard.dart';

ChildBadge _b(KidBadge badge,
        {String child = 'k1', DateTime? on, int progress = 0, int? target}) =>
    ChildBadge(
      childId: child,
      classId: 'c',
      badge: badge,
      earnedOn: on,
      progress: progress,
      target: target ?? 4,
    );

LeaderboardRow _row(String id, int points, {int badges = 0}) => LeaderboardRow(
      childId: id,
      childName: 'مخدوم $id',
      attendancePoints: points - badges * kBadgeBonus,
      badgesEarned: badges,
      gamePoints: points,
    );

Child _child({Gender gender = Gender.girl, String? mother}) => Child(
      id: 'k1',
      classId: 'c',
      fullName: 'إيريني رأفت',
      gender: gender,
      isActive: true,
      motherMobile: mother,
    );

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 900),
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      ),
    );

final _six = [
  _b(KidBadge.streak4, on: DateTime(2026, 11, 7)),
  _b(KidBadge.massMonth, on: DateTime(2026, 10, 31), target: 3),
  _b(KidBadge.fullDay, progress: 2, target: 5),
  _b(KidBadge.confession3, progress: 1, target: 3),
  _b(KidBadge.starMonth, target: 1),
  _b(KidBadge.streak16, progress: 6, target: 16),
];

void main() {
  _headerMergeTests();
  group('GameLevel', () {
    test('levels start at 0, 100, 300 and 600', () {
      expect(GameLevel.of(0), GameLevel.seed);
      expect(GameLevel.of(99), GameLevel.seed);
      expect(GameLevel.of(100), GameLevel.sprout);
      expect(GameLevel.of(299), GameLevel.sprout);
      expect(GameLevel.of(300), GameLevel.tree);
      expect(GameLevel.of(600), GameLevel.fruit);
      expect(GameLevel.of(5000), GameLevel.fruit);
    });

    test('points to the next level, and the share of the way', () {
      expect(GameLevel.toNext(245), 55);
      expect(GameLevel.progress(245), closeTo(0.725, 0.001));
      expect(GameLevel.toNext(700), 0);
      expect(GameLevel.progress(700), 1);
      expect(GameLevel.fruit.next, isNull);
    });
  });

  group('ChildBadge', () {
    test('reads a row; an unknown badge name is skipped', () {
      final b = ChildBadge.fromMap({
        'child_id': 'k',
        'class_id': 'c',
        'badge': 'full_day',
        'earned_on': '2026-11-21',
        'progress': 5,
        'target': 5,
      })!;
      expect(b.badge, KidBadge.fullDay);
      expect(b.earned, isTrue);
      expect(b.earnedOn, DateTime(2026, 11, 21));
      expect(ChildBadge.fromMap({'badge': 'something_new'}), isNull);
    });

    test('share is clamped and safe with no target', () {
      expect(_b(KidBadge.streak16, progress: 8, target: 16).share, 0.5);
      expect(_b(KidBadge.streak4, progress: 9, target: 4).share, 1);
      expect(_b(KidBadge.starMonth, target: 0).share, 0);
    });

    test('wonOn keeps the badges dated that very day', () {
      final day = DateTime(2026, 11, 21);
      final won = ChildBadge.wonOn([
        _b(KidBadge.streak4, on: DateTime(2026, 11, 21, 0)),
        _b(KidBadge.fullDay, on: DateTime(2026, 11, 14)),
        _b(KidBadge.massMonth),
      ], day);
      expect(won.map((b) => b.badge), [KidBadge.streak4]);
    });
  });

  group('newlyWon', () {
    final day = DateTime(2026, 11, 21);
    test('earned now and dated the saved Saturday', () {
      final wins = newlyWon(
        before: [_b(KidBadge.streak4, progress: 3)],
        after: [_b(KidBadge.streak4, on: day)],
        day: day,
      );
      expect(wins, hasLength(1));
      expect(wins.first.badge, KidBadge.streak4);
    });

    test('a re-saved Saturday does not announce it again', () {
      final wins = newlyWon(
        before: [_b(KidBadge.streak4, on: day)],
        after: [_b(KidBadge.streak4, on: day)],
        day: day,
      );
      expect(wins, isEmpty);
    });

    test('a badge dated another day is not this save\'s', () {
      final wins = newlyWon(
        before: const [],
        after: [_b(KidBadge.fullDay, on: DateTime(2026, 11, 14))],
        day: day,
      );
      expect(wins, isEmpty);
    });
  });

  group('LeaderboardRow.rankOf', () {
    final rows = [_row('a', 80), _row('b', 75), _row('c', 75), _row('d', 60)];
    test('places, ties sharing one', () {
      expect(LeaderboardRow.rankOf(rows, 'a'), 1);
      expect(LeaderboardRow.rankOf(rows, 'b'), 2);
      expect(LeaderboardRow.rankOf(rows, 'c'), 2);
      expect(LeaderboardRow.rankOf(rows, 'd'), 4);
      expect(LeaderboardRow.rankOf(rows, 'x'), isNull);
    });
  });

  group('ChildBadgesCard', () {
    testWidgets('points, level, rank and the badge grid', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: ChildBadgesCard(
          badges: _six,
          gamePoints: 245,
          rank: 3,
          onOpenRanking: () => opened++,
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('245'), findsOneWidget);
      expect(find.text(AppStrings.levelSprout), findsOneWidget);
      expect(find.text(AppStrings.toNextLevel(55, AppStrings.levelTree)),
          findsOneWidget);
      expect(find.text(AppStrings.badgesOf(2, 6)), findsOneWidget);
      // The run comes from the long-streak badge.
      expect(find.text(AppStrings.saturdaysInARow(6)), findsOneWidget);
      await tester.tap(find.text(AppStrings.rankInClass(3)));
      expect(opened, 1);
    });

    testWidgets('tapping a locked badge shows its rule and progress',
        (tester) async {
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: ChildBadgesCard(badges: _six, gamePoints: 245),
      )));
      await tester.pumpAndSettle();
      // The first (earned) badge is shown by default.
      expect(find.text(AppStrings.badgeStreak4Rule), findsOneWidget);
      final tile = find.bySemanticsLabel(AppStrings.badgeConfession3);
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.badgeConfession3Rule), findsOneWidget);
      expect(find.text(AppStrings.progressOf(1, 3)), findsOneWidget);
      expect(find.text(AppStrings.notYet), findsOneWidget);
    });

    testWidgets('no rank: no rank chip', (tester) async {
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: ChildBadgesCard(badges: _six, gamePoints: 0),
      )));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.inClassLink), findsNothing);
      expect(find.text(AppStrings.levelSeed), findsOneWidget);
    });

    testWidgets('fits a 320 px phone at 1.5x text', (tester) async {
      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ChildBadgesCard(badges: _six, gamePoints: 245, rank: 12),
          ),
        ),
        scale: 1.5,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('LeaderboardView', () {
    testWidgets('podium for three, the rest listed, the child marked',
        (tester) async {
      final rows = [
        _row('a', 80, badges: 1),
        _row('b', 75),
        _row('c', 70),
        _row('d', 60, badges: 2),
        _row('e', 50),
      ];
      await tester
          .pumpWidget(_app(LeaderboardView(rows: rows, highlightChildId: 'd')));
      await tester.pumpAndSettle();
      for (final r in rows) {
        expect(find.text(r.childName), findsOneWidget);
      }
      expect(find.text(AppStrings.badgesCount(2)), findsOneWidget);
      expect(find.text(AppStrings.rankingPointsNote), findsOneWidget);
    });

    testWidgets('nobody with points yet: the empty state', (tester) async {
      await tester.pumpWidget(_app(LeaderboardView(rows: [_row('a', 0)])));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.noRankingYet), findsOneWidget);
    });
  });

  testWidgets('RangeToggle switches between the month and the year',
      (tester) async {
    final picks = <bool>[];
    await tester
        .pumpWidget(_app(RangeToggle(month: true, onChanged: picks.add)));
    await tester.tap(find.text(AppStrings.rankingThisYear));
    await tester.tap(find.text(AppStrings.rankingThisMonth));
    expect(picks, [false, true]);
  });

  group('BadgeEarnedDialog', () {
    testWidgets('one child: the big card, bonus, WhatsApp for the family',
        (tester) async {
      await tester.pumpWidget(_app(BadgeEarnedDialog(wins: [
        (child: _child(mother: '01012345678'), badge: KidBadge.streak4),
      ])));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('${AppStrings.badgeStreak4}!'), findsOneWidget);
      expect(
          find.text(AppStrings.badgeWonBy(
              'إيريني رأفت', AppStrings.badgeStreak4,
              girl: true)),
          findsOneWidget);
      expect(find.text(AppStrings.badgeBonus(kBadgeBonus)), findsOneWidget);
      expect(find.text(AppStrings.congratsParents(girl: true)), findsOneWidget);
    });

    testWidgets('no family number: no WhatsApp button', (tester) async {
      await tester.pumpWidget(_app(BadgeEarnedDialog(wins: [
        (child: _child(gender: Gender.boy), badge: KidBadge.fullDay),
      ])));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(AppStrings.congratsParents(girl: false)), findsNothing);
      expect(find.text(AppStrings.badgeOk), findsOneWidget);
    });

    testWidgets('several children: one line each', (tester) async {
      await tester.pumpWidget(_app(BadgeEarnedDialog(wins: [
        (child: _child(mother: '01012345678'), badge: KidBadge.streak4),
        (child: _child(), badge: KidBadge.fullDay),
      ])));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(AppStrings.newBadgesCount(2)), findsOneWidget);
      expect(find.text(KidBadge.streak4.title), findsOneWidget);
      expect(find.text(KidBadge.fullDay.title), findsOneWidget);
      // Only the child with a number gets a congratulation button.
      expect(find.byIcon(Icons.chat_rounded), findsOneWidget);
    });
  });
}

void _headerMergeTests() {
  group('profile header merge', () {
    testWidgets('showPoints false: only the badge grid', (tester) async {
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: ChildBadgesCard(
          badges: _six,
          gamePoints: 245,
          showPoints: false,
          detailInSheet: true,
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.byType(GamePointsPanel), findsNothing);
      expect(find.text(AppStrings.badgesTitle), findsOneWidget);
      // No detail box under the grid.
      expect(find.text(KidBadge.streak4.rule), findsNothing);
    });

    testWidgets('detailInSheet: a tap opens the badge in a sheet',
        (tester) async {
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: ChildBadgesCard(
          badges: _six,
          gamePoints: 245,
          showPoints: false,
          detailInSheet: true,
        ),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text(KidBadge.fullDay.title));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text(KidBadge.fullDay.rule), findsOneWidget);
      expect(find.text(AppStrings.progressOf(2, 5)), findsOneWidget);
    });

    testWidgets('the panel can carry the attendance % and opens it',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(_app(Container(
        color: const Color(0xFF1B3A6B),
        child: GamePointsPanel(
          framed: false,
          points: 245,
          run: 2,
          rank: 3,
          attendancePct: 24.6,
          onOpenAttendance: () => opened++,
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('25%'), findsOneWidget);
      expect(find.text(AppStrings.attendanceChip), findsOneWidget);
      await tester.tap(find.text('25%'));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('three chips fit a small phone at large text', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(
        Container(
          color: const Color(0xFF1B3A6B),
          padding: const EdgeInsets.all(14),
          child: const GamePointsPanel(
            framed: false,
            points: 245,
            run: 12,
            rank: 10,
            attendancePct: 100,
          ),
        ),
        scale: 1.5,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
