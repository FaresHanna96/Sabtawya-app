import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/event.dart';
import 'package:sabtawya/features/events/events_screen.dart';

ChildEventBalance _b(String id,
        {double paid = 0, double cost = 100, bool reserved = false}) =>
    ChildEventBalance(
      eventId: 'e',
      childId: id,
      childName: id,
      classId: 'c',
      cost: cost,
      totalPaid: paid,
      remaining: cost - paid,
      reserved: reserved,
    );

final _event = Event(
  id: 'e',
  title: 'رحلة',
  eventDate: DateTime(2026, 11, 28),
  cost: 100,
  createdBy: 'u',
  createdAt: DateTime(2026, 11, 1),
);

Future<void> _pump(WidgetTester t, EventPaymentSummary? s) =>
    t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: EventMoneyBadge(event: _event, summary: s)),
      ),
    ));

void main() {
  group('EventPaymentSummary.of', () {
    test('booked = reserved or paid; unpaid = booked with money owing', () {
      final s = EventPaymentSummary.of([
        _b('a', paid: 100),
        _b('b', paid: 40),
        _b('c', reserved: true),
        _b('d'),
      ]);
      expect(s.booked, 3);
      expect(s.unpaid, 2);
      expect(s.collected, 140);
      expect(s.expected, 300);
      expect(s.allPaid, isFalse);
    });

    test('everyone who booked paid in full', () {
      final s = EventPaymentSummary.of([_b('a', paid: 100), _b('d')]);
      expect(s.allPaid, isTrue);
    });

    test('nobody booked', () {
      expect(EventPaymentSummary.of([_b('d')]).booked, 0);
      expect(const EventPaymentSummary().allPaid, isFalse);
    });
  });

  group('EventMoneyBadge', () {
    testWidgets('no summary or nobody booked: the cost', (t) async {
      await _pump(t, null);
      expect(find.text('100 ج.م'), findsOneWidget);
      await _pump(t, const EventPaymentSummary());
      expect(find.text('100 ج.م'), findsOneWidget);
    });

    testWidgets('some still owe: the count and money in', (t) async {
      await _pump(
          t,
          const EventPaymentSummary(
              booked: 4, unpaid: 3, collected: 59, expected: 400));
      expect(find.text(AppStrings.unpaidCount(3)), findsOneWidget);
      expect(find.text('59 / 400 ج.م'), findsOneWidget);
    });

    testWidgets('all paid', (t) async {
      await _pump(
          t,
          const EventPaymentSummary(
              booked: 2, unpaid: 0, collected: 200, expected: 200));
      expect(find.text(AppStrings.everyonePaid), findsOneWidget);
    });
  });
}
