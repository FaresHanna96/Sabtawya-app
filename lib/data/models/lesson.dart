import 'parsers.dart';

/// Where a lesson sits in the programme: the sheet's Coptic month (1 = توت …
/// 12 = مسرى) and week 1-4 inside it.
class LessonSlot {
  const LessonSlot(this.month, this.week);

  final int month;
  final int week;

  static const _months = <String>[
    'توت',
    'بابة',
    'هاتور',
    'كيهك',
    'طوبة',
    'أمشير',
    'برمهات',
    'برمودة',
    'بشنس',
    'بؤونة',
    'أبيب',
    'مسرى',
  ];

  /// "توت - الأسبوع 3".
  String get label => '${_months[month - 1]} - الأسبوع $week';

  @override
  bool operator ==(Object other) =>
      other is LessonSlot && other.month == month && other.week == week;

  @override
  int get hashCode => Object.hash(month, week);
}

/// One lesson of the weekly programme for a grade.
class Lesson {
  const Lesson({
    required this.slot,
    required this.grade,
    required this.title,
    this.page,
  });

  factory Lesson.fromMap(Map<String, dynamic> map) => Lesson(
        slot: LessonSlot(asInt(map['coptic_month']), asInt(map['week'])),
        grade: asInt(map['grade']),
        title: asText(map['title']),
        page: map['page'] == null ? null : asInt(map['page']),
      );

  final LessonSlot slot;
  final int grade;
  final String title;
  final int? page;
}

/// The المنبر and الترانيم/الألحان of a week, shared by every grade.
class LessonExtras {
  const LessonExtras({this.pulpit, this.hymns});

  factory LessonExtras.fromMap(Map<String, dynamic> map) => LessonExtras(
        pulpit: asTextOrNull(map['pulpit']),
        hymns: asTextOrNull(map['hymns']),
      );

  final String? pulpit;
  final String? hymns;
}

/// The whole programme: 48 lessons per grade, 4 weeks to each Coptic month.
///
/// Lesson 1 (توت week 1) is the first Saturday of the Coptic year (the first
/// one on or after 1 Tout, September 11 or 12) and every Saturday after it
/// takes the next lesson, so 7 Nov 2026 is هاتور week 1. A Saturday before
/// the programme starts or after lesson 48 has none.
class LessonProgramme {
  const LessonProgramme(
    this._lessons,
    this._extras, [
    this._breaks = const <String, bool>{},
  ]);

  static const empty =
      LessonProgramme(<Lesson>[], <LessonSlot, LessonExtras>{});

  static const lessonCount = 48;

  final List<Lesson> _lessons;
  final Map<LessonSlot, LessonExtras> _extras;

  /// Weeks without a lesson, keyed by `yyyy-MM-dd`; the value is `shift`
  /// (true = postponed, later lessons move on; false = cancelled).
  final Map<String, bool> _breaks;

  static String keyOf(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// null = a normal week, true = postponed, false = cancelled.
  bool? breakOn(DateTime saturday) => _breaks[keyOf(saturday)];

  bool get isEmpty => _lessons.isEmpty;

  static bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  /// The first session day (weekday [weekday], 1 = Monday) on or after 1 Tout
  /// of the Coptic year that [anyDayInYear] falls in.
  static DateTime programmeStart(DateTime anyDayInYear, int weekday) {
    DateTime newYear(int y) => DateTime(y, 9, _isLeap(y + 1) ? 12 : 11);
    var start = newYear(anyDayInYear.year);
    if (anyDayInYear.isBefore(start)) start = newYear(anyDayInYear.year - 1);
    while (start.weekday != weekday) {
      start = DateTime(start.year, start.month, start.day + 1);
    }
    return start;
  }

  /// The slot of the week of [date], counting weekly from [firstDay] (the
  /// programme start). A postponed week gives its lesson to the next week, a
  /// cancelled week drops it; null for those weeks, before the start and after
  /// the last lesson.
  LessonSlot? slotOn(DateTime date, DateTime firstDay) {
    final days = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(firstDay.year, firstDay.month, firstDay.day))
        .inDays;
    if (days < 0) return null;
    final week = days ~/ 7;

    var lesson = 0;
    for (var w = 0; w <= week; w++) {
      final saturday =
          DateTime(firstDay.year, firstDay.month, firstDay.day + 7 * w);
      final shift = _breaks[keyOf(saturday)];
      if (w == week) {
        if (shift != null || lesson >= lessonCount) return null;
        return LessonSlot(lesson ~/ 4 + 1, lesson % 4 + 1);
      }
      // A postponed week keeps its lesson for later; any other week uses one.
      if (shift != true) lesson++;
    }
    return null;
  }

  /// Every grade's lesson in [slot] (for the admin editor).
  List<Lesson> lessonsAt(LessonSlot slot) =>
      _lessons.where((l) => l.slot == slot).toList()
        ..sort((a, b) => a.grade.compareTo(b.grade));

  LessonExtras? extrasAt(LessonSlot slot) => _extras[slot];

  Lesson? lessonOn(DateTime date, int grade, {required DateTime firstDay}) {
    final slot = slotOn(date, firstDay);
    if (slot == null) return null;
    for (final lesson in _lessons) {
      if (lesson.slot == slot && lesson.grade == grade) return lesson;
    }
    return null;
  }

  LessonExtras? extrasOn(DateTime date, {required DateTime firstDay}) {
    final slot = slotOn(date, firstDay);
    return slot == null ? null : _extras[slot];
  }

  /// The grade a class belongs to: the leading digit of its name ("5 ولاد").
  static int? gradeOf(String className) {
    final match = RegExp(r'^\s*([3-6])').firstMatch(className);
    return match == null ? null : int.parse(match.group(1)!);
  }
}
