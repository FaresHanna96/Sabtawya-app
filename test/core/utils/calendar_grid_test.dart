import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/calendar_grid.dart';

void main() {
  group('weeks', () {
    test('November 2026 starts on a Sunday: one blank after Saturday', () {
      final w = CalendarGrid.weeks(2026, 11);
      expect(w.first.first, isNull); // Saturday 31 Oct is not in the month
      expect(w.first[1], DateTime(2026, 11, 1));
      expect(w.every((row) => row.length == 7), isTrue);
    });

    test('a month starting on Saturday has no leading blanks', () {
      final w = CalendarGrid.weeks(2026, 8); // 1 Aug 2026 is a Saturday
      expect(w.first.first, DateTime(2026, 8, 1));
    });

    test('a month starting on Friday has six leading blanks', () {
      final w = CalendarGrid.weeks(2027, 1); // 1 Jan 2027 is a Friday
      expect(w.first.sublist(0, 6).every((c) => c == null), isTrue);
      expect(w.first.last, DateTime(2027, 1, 1));
    });

    test('every day of the month appears exactly once', () {
      for (var m = 1; m <= 12; m++) {
        final days = CalendarGrid.weeks(2026, m)
            .expand((r) => r)
            .whereType<DateTime>()
            .toList();
        expect(days.length, CalendarGrid.daysIn(2026, m));
        expect(days.first.day, 1);
        expect(days.last.day, CalendarGrid.daysIn(2026, m));
      }
    });

    test('Saturdays fall in the first column', () {
      for (final row in CalendarGrid.weeks(2026, 11)) {
        final d = row.first;
        if (d != null) expect(d.weekday, DateTime.saturday);
      }
    });
  });

  group('birthdays', () {
    test('a birthday repeats on the same day each year', () {
      expect(CalendarGrid.birthdayIn(DateTime(2017, 3, 31), 2026),
          DateTime(2026, 3, 31));
    });

    test('29 February falls on the 28th in a year without one', () {
      final birth = DateTime(2016, 2, 29);
      expect(CalendarGrid.birthdayIn(birth, 2026), DateTime(2026, 2, 28));
      expect(CalendarGrid.birthdayIn(birth, 2028), DateTime(2028, 2, 29));
    });
  });
}
