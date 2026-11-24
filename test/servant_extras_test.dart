import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/data/models/profile.dart';
import 'package:sabtawya/data/models/servant_activity.dart';
import 'package:sabtawya/features/servant_activities/admin_servant_activities_screen.dart';
import 'package:sabtawya/features/servant_activities/servant_badges.dart';
import 'package:sabtawya/features/servant_activities/servant_covers.dart';
import 'package:sabtawya/features/servant_activities/servant_follow_up_card.dart';
import 'package:sabtawya/features/servant_activities/servant_year.dart';

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 800),
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ),
        ),
      ),
    );

Profile _p(String id, String name) => Profile(
      id: id,
      fullName: name,
      role: AppRole.servant,
      isActive: true,
    );

ServantAttendance _m(String servant, String type, DateTime d) =>
    ServantAttendance.fromMap({
      'id': '$servant-$type-${d.toIso8601String()}',
      'servant_id': servant,
      'activity_type': type,
      'date': d.toIso8601String().substring(0, 10),
      'recorded_by': 'admin',
    });

void main() {
  group('orderServantsByClass', () {
    test('class order first, general servants last, names within', () {
      final out = orderServantsByClass(
        [
          _p('g', 'أمير'),
          _p('b2', 'يوسف'),
          _p('a', 'مينا'),
          _p('b1', 'بيشوي'),
        ],
        classIdOf: {'a': 'c1', 'b1': 'c2', 'b2': 'c2'},
        classOrder: {'c2': 0, 'c1': 1},
      );
      expect(out.map((p) => p.id), ['b1', 'b2', 'a', 'g']);
    });
  });

  group('ServantMonthReport', () {
    final sats = [
      DateTime(2026, 11, 7),
      DateTime(2026, 11, 14),
      DateTime(2026, 11, 21),
      DateTime(2026, 10, 31),
    ];
    final year = ServantYear(
      heldSaturdays: sats,
      marks: [
        _m('a', 'sunday_school', sats[0]),
        _m('a', 'sunday_school', sats[1]),
        _m('a', 'mass', sats[2]),
        _m('a', 'sunday_school', sats[3]), // October, not counted
      ],
      preps: const [],
      today: DateTime(2026, 11, 23),
    );

    test('counts the month only, with the preps', () {
      final r = ServantMonthReport.of(
        year,
        'a',
        DateTime(2026, 11),
        prepsSent: 3,
        prepsAccepted: 2,
      );
      expect(r.held, 3);
      expect(r.counts['sunday_school'], 2);
      expect(r.counts['mass'], 1);
      final text = r.text('مينا سمير');
      expect(text, contains('مينا:'));
      expect(text, isNot(contains('سمير')));
      expect(
          text, contains('${AppStrings.chipService} 2 ${AppStrings.ofWord} 3'));
      expect(text, contains(AppStrings.reportPreps(3, 2)));
    });
  });

  group('ServantBadgesCard', () {
    const states = [
      ServantBadgeState(ServantBadge.faithful, earned: true, progress: 4),
      ServantBadgeState(ServantBadge.greatPrep, earned: false, progress: 2),
      ServantBadgeState(ServantBadge.meeting, earned: false),
      ServantBadgeState(ServantBadge.confession, earned: false, progress: 1),
    ];

    testWidgets('shows the four with the earned count and progress',
        (tester) async {
      await tester.pumpWidget(_app(const ServantBadgesCard(badges: states)));
      expect(find.text(AppStrings.badgesOf(1, 4)), findsOneWidget);
      expect(find.text(AppStrings.servantBadgeFaithful), findsOneWidget);
      expect(find.text(AppStrings.progressOf(2, 5)), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(3));
    });

    testWidgets('fits 320 px at 1.5× text', (tester) async {
      await tester.pumpWidget(
          _app(const ServantBadgesCard(badges: states), scale: 1.5));
      expect(tester.takeException(), isNull);
    });
  });

  group('ServantFollowUpCard', () {
    testWidgets('hidden when nobody needs following up', (tester) async {
      await tester.pumpWidget(
          _app(const ServantFollowUpCard(entries: [], senderName: 'أبونا')));
      expect(find.text(AppStrings.needsAttention), findsNothing);
    });

    testWidgets('lists the reason and a WhatsApp message', (tester) async {
      const e = ServantFollowUpEntry(
        followUp: ServantFollowUp('a', ServantFollowUpReason.absent, 3),
        name: 'مينا سمير',
        mobile: '01012345678',
      );
      await tester.pumpWidget(
          _app(const ServantFollowUpCard(entries: [e], senderName: 'أبونا')));
      expect(find.text(AppStrings.needsAttention), findsOneWidget);
      expect(
          find.textContaining(AppStrings.servantAbsentRun(3)), findsOneWidget);
      expect(servantFollowUpMessage(e, 'أبونا'), contains('مينا'));
    });
  });

  testWidgets('embedded follow-up fits 320 px at 1.5× text', (tester) async {
    const e = ServantFollowUpEntry(
      followUp: ServantFollowUp('a', ServantFollowUpReason.preps, 2),
      name: 'خادم عام تجريبي بإسم طويل جدا',
      mobile: '01012345678',
      className: '3 ولاد',
    );
    await tester.pumpWidget(_app(
        ServantFollowUpCard(
          embedded: true,
          entries: const [e, e],
          senderName: 'أبونا',
          onOpen: (_) {},
        ),
        scale: 1.5));
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.needsAttention), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('TrendArrow says up or down', (tester) async {
    await tester.pumpWidget(_app(const Row(children: [
      TrendArrow(points: 25),
      TrendArrow(points: -12),
    ])));
    expect(find.byTooltip(AppStrings.trendUp(25)), findsOneWidget);
    expect(find.byTooltip(AppStrings.trendDown(12)), findsOneWidget);
  });

  group('substitutes', () {
    test('ServantSubstitute.fromMap', () {
      final s = ServantSubstitute.fromMap({
        'id': '1',
        'date': '2026-11-21',
        'class_id': 'c',
        'absent_servant_id': 'a',
        'substitute_servant_id': 'b',
      });
      expect(s.date, DateTime(2026, 11, 21));
      expect(s.substituteServantId, 'b');
    });

    testWidgets('footer asks «مين غطّى؟» and undoes a cover', (tester) async {
      var asked = 0;
      var removed = 0;
      await tester.pumpWidget(_app(ServantCoverFooter(onAsk: () => asked++)));
      await tester.tap(find.text(AppStrings.whoCovered));
      expect(asked, 1);

      await tester.pumpWidget(_app(ServantCoverFooter(
        coveredBy: [(name: 'بيشوي', onRemove: () => removed++)],
        coveredFor: const ['يوسف'],
      )));
      expect(find.text(AppStrings.coveredBy('بيشوي')), findsOneWidget);
      expect(find.text(AppStrings.coveredFor('يوسف')), findsOneWidget);
      expect(find.text(AppStrings.whoCovered), findsNothing);
      await tester.tap(find.byTooltip(AppStrings.removeSubstitute));
      expect(removed, 1);
    });

    testWidgets('covers card reads from the servant\'s side', (tester) async {
      final subs = [
        ServantSubstitute(
          id: '1',
          date: DateTime(2026, 11, 21),
          classId: 'c',
          absentServantId: 'a',
          substituteServantId: 'me',
        ),
        ServantSubstitute(
          id: '2',
          date: DateTime(2026, 11, 14),
          classId: 'c',
          absentServantId: 'me',
          substituteServantId: 'b',
        ),
      ];
      final names = {'a': 'مينا', 'b': 'بيشوي'};
      await tester.pumpWidget(_app(ServantCoversCard(
        servantId: 'me',
        subs: subs,
        nameOf: (id) => names[id] ?? '',
      )));
      expect(find.textContaining('غطّى بدل مينا'), findsOneWidget);
      expect(find.textContaining('بيشوي غطّى مكانه'), findsOneWidget);
    });

    testWidgets('covers card is hidden when empty', (tester) async {
      await tester.pumpWidget(_app(ServantCoversCard(
        servantId: 'me',
        subs: const [],
        nameOf: (_) => '',
      )));
      expect(find.text(AppStrings.coversTitle), findsNothing);
    });
  });
}
