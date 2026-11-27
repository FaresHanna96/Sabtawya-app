import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/models/event.dart';
import 'package:sabtawya/features/attendance/attendance_screen.dart';

final _year = AttendanceYear(
  id: 'year-1',
  name: '2026 - 2027',
  startDate: DateTime(2026, 9, 26),
  endDate: DateTime(2027, 6, 26),
  sessionWeekday: 6,
  pointsSundaySchool: 5,
  pointsVespers: 5,
  pointsMass: 5,
  pointsConfession: 5,
  maxPointsPerSession: 20,
  isCurrent: true,
);

AttendanceEntry _entry() => AttendanceEntry.from(
      child: const Child(
        id: 'a',
        classId: 'c',
        fullName: 'مخدوم a',
        gender: Gender.boy,
        isActive: true,
      ),
      year: _year,
      record: const AttendanceRecord(
        sessionId: 's',
        childId: 'a',
        sundaySchool: false,
        vespers: false,
        mass: false,
        confession: false,
        score: 0,
        maxScore: 20,
      ),
    );

ChildEventBalance _line({double paid = 0, bool reserved = false}) =>
    ChildEventBalance(
      eventId: 'e',
      childId: 'a',
      childName: 'مخدوم a',
      classId: 'c',
      cost: 100,
      totalPaid: paid,
      remaining: 100 - paid,
      reserved: reserved,
    );

Widget _rtl(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('a child\'s booking line', () {
    test('nothing: not booked, not paid', () {
      final l = _line();
      expect([l.isBooked, l.isPaid], [false, false]);
    });

    test('reserved: booked, not paid', () {
      final l = _line(reserved: true);
      expect([l.isBooked, l.isPaid], [true, false]);
    });

    test('paid something: booked even without a reservation', () {
      final l = _line(paid: 20);
      expect([l.isBooked, l.isPaid], [true, true]);
    });
  });

  group('the booking chip on a card', () {
    Future<void> pump(
      WidgetTester tester,
      EntryBooking? booking,
      VoidCallback? onBook,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_rtl(AttendanceEntryCard(
        entry: _entry(),
        enabled: true,
        onToggle: (_) {},
        booking: booking,
        onBook: onBook,
      )));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('no upcoming event: no chip', (tester) async {
      await pump(tester, null, null);
      for (final t in [
        AppStrings.bookShort,
        AppStrings.bookedShort,
        AppStrings.bookedPaidShort,
      ]) {
        expect(find.text(t), findsNothing);
      }
    });

    testWidgets('not booked: says حجز and a tap books', (tester) async {
      var taps = 0;
      await pump(tester, EntryBooking.none, () => taps++);
      await tester.tap(find.text(AppStrings.bookShort));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('booked: says محجوز and a tap reports it', (tester) async {
      var taps = 0;
      await pump(tester, EntryBooking.reserved, () => taps++);
      await tester.tap(find.text(AppStrings.bookedShort));
      expect(taps, 1);
    });

    testWidgets('paid: says دفع and a tap opens the sheet too', (tester) async {
      var taps = 0;
      await pump(tester, EntryBooking.paid, () => taps++);
      await tester.tap(find.text(AppStrings.bookedPaidShort));
      expect(taps, 1);
    });

    testWidgets('the four toggles still work next to it', (tester) async {
      final tapped = <AttendanceActivity>[];
      await tester.pumpWidget(_rtl(AttendanceEntryCard(
        entry: _entry(),
        enabled: true,
        onToggle: tapped.add,
        booking: EntryBooking.none,
        onBook: () {},
      )));
      await tester.tap(find.text(AppStrings.massShort));
      expect(tapped, [AttendanceActivity.mass]);
    });
  });

  group('the booking mark on a compact line', () {
    testWidgets('only with an event, and it books', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_rtl(SizedBox(
        width: 375,
        child: AttendanceEntryRow(
          entry: _entry(),
          enabled: true,
          onToggle: (_) {},
          booking: EntryBooking.none,
          onBook: () => taps++,
        ),
      )));
      await tester.tap(find.byTooltip(AppStrings.bookShort));
      expect(taps, 1);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_rtl(SizedBox(
        width: 375,
        child: AttendanceEntryRow(
          entry: _entry(),
          enabled: true,
          onToggle: (_) {},
        ),
      )));
      expect(find.byTooltip(AppStrings.bookShort), findsNothing);
    });

    testWidgets('paid: a tap still reports', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_rtl(SizedBox(
        width: 375,
        child: AttendanceEntryRow(
          entry: _entry(),
          enabled: true,
          onToggle: (_) {},
          booking: EntryBooking.paid,
          onBook: () => taps++,
        ),
      )));
      await tester.tap(find.byTooltip(AppStrings.bookedPaidShort));
      expect(taps, 1);
    });
  });
}
