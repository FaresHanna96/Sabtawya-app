/// Arabic date formatting with Latin digits.
///
/// Written by hand rather than through `intl` because the Arabic locale there
/// renders Arabic-Indic numerals, and the project convention keeps numbers in
/// Latin digits.
class AppDateUtils {
  const AppDateUtils._();

  static const List<String> months = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  /// Indexed by `DateTime.weekday` (1 = Monday ... 7 = Sunday).
  static const List<String> weekdays = <String>[
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  static String monthName(int month) => months[month - 1];

  static String weekdayName(DateTime date) => weekdays[date.weekday - 1];

  /// `24 أكتوبر 2026`
  static String formatDate(DateTime date) =>
      '${date.day} ${monthName(date.month)} ${date.year}';

  /// `السبت، 24 أكتوبر 2026`
  static String formatDayDate(DateTime date) =>
      '${weekdayName(date)}، ${formatDate(date)}';

  /// `أكتوبر 2026`
  static String formatMonth(DateTime date) =>
      '${monthName(date.month)} ${date.year}';

  /// `24 أكتوبر 2026 - 08:30 م`
  static String formatDateTime(DateTime date) {
    final local = date.toLocal();
    return '${formatDate(local)} - ${formatTime(local)}';
  }

  /// `08:30 م`
  static String formatTime(DateTime date) {
    final local = date.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour < 12 ? 'ص' : 'م';
    return '${hour12.toString().padLeft(2, '0')}:$minute $suffix';
  }

  /// A day the way people say it: `اليوم`, `أمس`, otherwise
  /// `الجمعة 13 نوفمبر` (with the year only when it is not this one).
  static String dayLabel(DateTime date, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final day = dateOnly(date);
    final days = daysBetween(day, today);
    if (days == 0) return 'اليوم';
    if (days == 1) return 'أمس';
    final year = day.year == today.year ? '' : ' ${day.year}';
    return '${weekdayName(day)} ${day.day} ${monthName(day.month)}$year';
  }

  /// `2026-10-24`, the wire format for Postgres `date` columns.
  static String toIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Whole calendar days from [from] to [to]. Not `difference().inDays`: the
  /// day the clocks go forward is 23 hours long and would count as none.
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The Saturday on or before [from]; used to default the attendance screen
  /// to the most recent session.
  static DateTime lastSaturday(DateTime from) {
    final date = dateOnly(from);
    final diff = (date.weekday - DateTime.saturday + 7) % 7;
    return DateTime(date.year, date.month, date.day - diff);
  }

  /// The first Saturday on or after [from] (today when omitted).
  static DateTime nextSaturday([DateTime? from]) {
    final date = dateOnly(from ?? DateTime.now());
    return DateTime(date.year, date.month,
        date.day + (DateTime.saturday - date.weekday) % 7);
  }

  /// Whether someone born on [birth] has their birthday on [day]. A 29 February
  /// birthday falls on the 28th in a year without one, so it is never skipped.
  static bool isBirthdayOn(DateTime birth, DateTime day) {
    if (birth.month != day.month) return false;
    if (birth.day == day.day) return true;
    final leap = DateTime(day.year, 2, 29).month == 2;
    return birth.month == 2 && birth.day == 29 && day.day == 28 && !leap;
  }

  /// "الآن", "منذ 5 دقائق", "منذ ساعتين" within the day; after that the
  /// day-level wording of [sinceLabel] and the date and time.
  static String agoLabel(DateTime at, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(at.toLocal());
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) {
      return _count(diff.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق');
    }
    if (diff.inHours < 24) {
      return _count(diff.inHours, 'ساعة', 'ساعتين', 'ساعات');
    }
    return '${sinceLabel(at, now: now)} • ${formatDateTime(at)}';
  }

  /// Arabic counting: one, two, 3 to 10 take the plural, 11 and up the
  /// singular ("منذ 5 دقائق" but "منذ 15 دقيقة").
  static String _count(int n, String one, String two, String few) =>
      switch (n) {
        1 => 'منذ $one',
        2 => 'منذ $two',
        <= 10 => 'منذ $n $few',
        _ => 'منذ $n $one',
      };

  /// How long ago [date] was, in Arabic: `اليوم`, `منذ أسبوعين`, `منذ 5 أسابيع`.
  ///
  /// Arabic counts in three shapes - one, two, and many - so a plain
  /// "منذ 1 أسبوع" would read wrong.
  static String sinceLabel(DateTime date, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final days = daysBetween(date, today);

    if (days <= 0) return 'اليوم';
    if (days < 7) {
      return switch (days) {
        1 => 'منذ يوم',
        2 => 'منذ يومين',
        _ => 'منذ $days أيام',
      };
    }

    final weeks = days ~/ 7;
    if (weeks < 5) {
      return switch (weeks) {
        1 => 'منذ أسبوع',
        2 => 'منذ أسبوعين',
        _ => 'منذ $weeks أسابيع',
      };
    }

    final months = days ~/ 30;
    if (months < 12) {
      return switch (months) {
        1 => 'منذ شهر',
        2 => 'منذ شهرين',
        _ => 'منذ $months أشهر',
      };
    }

    final years = days ~/ 365;
    return switch (years) {
      1 => 'منذ سنة',
      2 => 'منذ سنتين',
      _ => 'منذ $years سنوات',
    };
  }
}
