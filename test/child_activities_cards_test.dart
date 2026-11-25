import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/competition.dart';
import 'package:sabtawya/data/models/event.dart';
import 'package:sabtawya/features/children/profile/child_activities_cards.dart';

final _year = AttendanceYear(
  id: 'y',
  name: '2026 - 2027',
  startDate: DateTime(2026, 9, 26),
  endDate: DateTime(2027, 9, 25),
  sessionWeekday: 6,
  pointsSundaySchool: 5,
  pointsVespers: 5,
  pointsMass: 5,
  pointsConfession: 5,
  maxPointsPerSession: 20,
  isCurrent: true,
);

final _today = DateTime(2026, 11, 23);

Event _event(String id, DateTime date, {double cost = 200, String? yearId}) =>
    Event(
      id: id,
      title: 'رحلة $id',
      eventDate: date,
      cost: cost,
      yearId: yearId,
      createdBy: 'a',
      createdAt: DateTime(2026, 9, 1),
    );

ChildEventBalance _bal(String eventId,
        {double cost = 200, double paid = 0, bool reserved = false}) =>
    ChildEventBalance(
      eventId: eventId,
      childId: 'k1',
      childName: 'مينا',
      classId: 'c',
      cost: cost,
      totalPaid: paid,
      remaining: cost - paid,
      reserved: reserved,
    );

Competition _comp(String id, DateTime week, {int max = 10, String? yearId}) =>
    Competition(
      id: id,
      title: 'مسابقة $id',
      weekDate: week,
      maxMark: max,
      createdBy: 'a',
      createdAt: week,
      yearId: yearId,
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
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

void main() {
  group('ChildTrip.of', () {
    final events = [
      _event('past-booked', DateTime(2026, 10, 10)),
      _event('past-skipped', DateTime(2026, 10, 17)),
      _event('soon', DateTime(2026, 12, 5)),
      _event('later', DateTime(2027, 1, 9)),
      _event('last-year', DateTime(2026, 5, 1)),
      _event('other-year', DateTime(2026, 11, 28), yearId: 'old'),
    ];
    final balances = [
      _bal('past-booked', paid: 200),
      _bal('past-skipped'),
      _bal('soon', reserved: true),
      _bal('later'),
      _bal('last-year', paid: 50),
      _bal('other-year', paid: 100),
    ];

    test('keeps only the coming ones of this year, nearest first', () {
      final trips = ChildTrip.of(
        events: events,
        balances: balances,
        today: _today,
        year: _year,
      );
      // The past trip the child booked and paid is not listed any more.
      expect(trips.map((t) => t.event.id), ['soon', 'later']);
    });

    test('a trip today still counts as coming', () {
      final trips = ChildTrip.of(
        events: [_event('today', _today)],
        balances: [_bal('today')],
        today: DateTime(2026, 11, 23, 18),
        year: _year,
      );
      expect(trips.single.state, TripState.open);
    });

    test('an event with no line for the child is left out', () {
      expect(
        ChildTrip.of(
          events: [_event('x', DateTime(2026, 12, 1))],
          balances: const [],
          today: _today,
          year: _year,
        ),
        isEmpty,
      );
    });

    test('states and what is still owed', () {
      final paid = ChildTrip(_event('a', _today), _bal('a', paid: 200));
      final partly = ChildTrip(_event('b', _today), _bal('b', paid: 50));
      final reserved =
          ChildTrip(_event('c', _today), _bal('c', reserved: true));
      final open = ChildTrip(_event('d', _today), _bal('d'));
      expect(paid.state, TripState.paid);
      expect(partly.state, TripState.partly);
      expect(reserved.state, TripState.reserved);
      expect(open.state, TripState.open);
      // Not booked owes nothing; the others owe what is left.
      expect(ChildTrip.owed([paid, partly, reserved, open]), 150 + 200);
    });
  });

  test('ChildCompetitionsCard.forYear keeps this year by id or by date', () {
    final marks = [
      (_comp('in', DateTime(2026, 11, 7), yearId: 'y'), 8),
      (_comp('dated', DateTime(2026, 10, 3)), 6),
      (_comp('old', DateTime(2026, 11, 14), yearId: 'old'), 9),
      (_comp('before', DateTime(2026, 6, 6)), 7),
    ];
    expect(
      ChildCompetitionsCard.forYear(marks, _year).map((m) => m.$1.id),
      ['in', 'dated'],
    );
    expect(ChildCompetitionsCard.forYear(marks, null), hasLength(4));
  });

  group('ChildTripsCard', () {
    testWidgets('shows each state and what is owed', (tester) async {
      Event? opened;
      final trips = [
        ChildTrip(_event('a', DateTime(2026, 12, 5)),
            _bal('a', cost: 250, paid: 100)),
        ChildTrip(_event('b', DateTime(2026, 12, 12)), _bal('b')),
        ChildTrip(_event('c', DateTime(2026, 10, 10)), _bal('c', paid: 200)),
      ];
      await tester.pumpWidget(_app(
        ChildTripsCard(trips: trips, onOpen: (e) => opened = e),
      ));
      expect(find.text(AppStrings.tripsOwed('150 جنيه')), findsOneWidget);
      expect(find.text(AppStrings.tripPaidOf('100 جنيه', '250 جنيه')),
          findsOneWidget);
      expect(find.text(AppStrings.tripNotBooked), findsOneWidget);
      expect(find.text(AppStrings.paidInFull), findsOneWidget);
      expect(find.text(AppStrings.moreTrips(1)), findsNothing);

      await tester.tap(find.text('رحلة b'));
      expect(opened?.id, 'b');
    });

    testWidgets('more than three: «و2 نشاطات كمان» opens them all',
        (tester) async {
      final trips = [
        for (var i = 0; i < 5; i++)
          ChildTrip(_event('t$i', DateTime(2026, 12, 1 + i)),
              _bal('t$i', reserved: true)),
      ];
      await tester.pumpWidget(_app(ChildTripsCard(trips: trips)));
      expect(find.text('رحلة t3'), findsNothing);
      expect(find.text(AppStrings.reservedUnpaidStatus), findsNWidgets(3));

      await tester.tap(find.text(AppStrings.moreTrips(2)));
      await tester.pumpAndSettle();
      expect(find.text('رحلة t4'), findsOneWidget);
    });

    testWidgets('no owed line when everything is paid', (tester) async {
      await tester.pumpWidget(_app(ChildTripsCard(trips: [
        ChildTrip(_event('a', DateTime(2026, 12, 5)), _bal('a', paid: 200)),
      ])));
      expect(find.textContaining('لسه باقي'), findsNothing);
    });
  });

  group('ChildCompetitionsCard', () {
    testWidgets('the total, the count and the last three weeks',
        (tester) async {
      Competition? opened;
      final marks = [
        (_comp('4', DateTime(2026, 11, 21)), 9),
        (_comp('3', DateTime(2026, 11, 14)), 7),
        (_comp('2', DateTime(2026, 11, 7), max: 20), 15),
        (_comp('1', DateTime(2026, 10, 31)), 4),
      ];
      await tester.pumpWidget(_app(
        ChildCompetitionsCard(marks: marks, onOpen: (c) => opened = c),
      ));
      expect(find.text(AppStrings.marksOf(35, 50)), findsOneWidget);
      expect(find.text(AppStrings.inCompetitions(4)), findsOneWidget);
      expect(find.textContaining('مسابقة 1'), findsNothing);
      expect(find.text(AppStrings.marksOf(15, 20)), findsOneWidget);

      await tester.tap(find.text(AppStrings.marksOf(7, 10)));
      expect(opened?.id, '3');
    });
  });

  testWidgets('both cards fit a 320 px phone at 1.5x text', (tester) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(
      Column(
        children: [
          ChildTripsCard(trips: [
            ChildTrip(
              _event('رحلة طويلة جدا لدير الأنبا بيشوي ووادي النطرون',
                  DateTime(2026, 12, 5)),
              _bal('رحلة طويلة جدا لدير الأنبا بيشوي ووادي النطرون',
                  cost: 1250, paid: 375.5),
            ),
          ]),
          ChildCompetitionsCard(marks: [
            (_comp('طويلة جدا عن حياة القديسين', DateTime(2026, 11, 21)), 9),
          ]),
        ],
      ),
      scale: 1.5,
    ));
    expect(tester.takeException(), isNull);
  });
}
