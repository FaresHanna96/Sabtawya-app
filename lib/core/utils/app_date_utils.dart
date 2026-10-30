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
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour < 12 ? 'ص' : 'م';
    return '${formatDate(local)} - '
        '${hour12.toString().padLeft(2, '0')}:$minute $suffix';
  }

  /// `2026-10-24`, the wire format for Postgres `date` columns.
  static String toIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime parseIsoDate(String value) {
    final parsed = DateTime.parse(value);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The Saturday on or before [from]; used to default the attendance screen
  /// to the most recent session.
  static DateTime lastSaturday(DateTime from) {
    final date = dateOnly(from);
    final diff = (date.weekday - DateTime.saturday + 7) % 7;
    return date.subtract(Duration(days: diff));
  }

  static String formatPercentage(num value) =>
      '${value.toStringAsFixed(1)}%';

  /// How long ago [date] was, in Arabic: `اليوم`, `منذ أسبوعين`, `منذ 5 أسابيع`.
  ///
  /// Arabic counts in three shapes - one, two, and many - so a plain
  /// "منذ 1 أسبوع" would read wrong.
  static String sinceLabel(DateTime date, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final days = today.difference(dateOnly(date)).inDays;

    if (days <= 0) return 'اليوم';
    if (days < 7) return days == 1 ? 'منذ يوم' : 'منذ $days أيام';

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
