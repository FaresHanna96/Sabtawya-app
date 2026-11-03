/// Date maths for the month calendar. The week starts on Saturday, the day the
/// sessions are held.
class CalendarGrid {
  const CalendarGrid._();

  /// Day names for the header, Saturday first.
  static const weekdayInitials = <String>['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

  static bool isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  static int daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

  /// Weeks of a month as rows of 7; cells outside the month are null.
  static List<List<DateTime?>> weeks(int year, int month) {
    final first = DateTime(year, month, 1);
    final lead = (first.weekday - DateTime.saturday) % 7;
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= daysIn(year, month); d++) DateTime(year, month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [
      for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7),
    ];
  }

  /// The date of [birth]'s birthday in [year]; 29 February falls on the 28th
  /// in a year without one.
  static DateTime birthdayIn(DateTime birth, int year) {
    if (birth.month == 2 && birth.day == 29 && !isLeap(year)) {
      return DateTime(year, 2, 28);
    }
    return DateTime(year, birth.month, birth.day);
  }

  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
