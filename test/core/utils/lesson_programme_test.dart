import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/lesson.dart';

void main() {
  // 1 Tout 1743 is Friday 11 Sep 2026, so the programme starts Saturday 12 Sep.
  final start = DateTime(2026, 9, 12);

  final programme = LessonProgramme(
    const [
      Lesson(slot: LessonSlot(1, 1), grade: 3, title: 'الأول', page: 19),
      Lesson(slot: LessonSlot(3, 1), grade: 3, title: 'هاتور الأول', page: 86),
      Lesson(slot: LessonSlot(12, 4), grade: 3, title: 'الأخير', page: 145),
    ],
    {const LessonSlot(3, 1): const LessonExtras(pulpit: 'منبر')},
  );

  test('the grade comes from the class name', () {
    expect(LessonProgramme.gradeOf('3 ولاد'), 3);
    expect(LessonProgramme.gradeOf('6 بنات'), 6);
    expect(LessonProgramme.gradeOf('6 بنات 2027'), 6);
    expect(LessonProgramme.gradeOf('فصل'), isNull);
    expect(LessonProgramme.gradeOf('2 ولاد'), isNull);
  });

  group('programme start', () {
    test('first Saturday on or after 1 Tout', () {
      expect(LessonProgramme.programmeStart(DateTime(2026, 10, 24), 6), start);
      expect(LessonProgramme.programmeStart(DateTime(2027, 3, 1), 6), start);
    });

    test('1 Tout is September 12 before a Gregorian leap year', () {
      // 12 Sep 2023 is a Tuesday; the first Saturday after is 16 Sep.
      expect(LessonProgramme.programmeStart(DateTime(2023, 10, 1), 6),
          DateTime(2023, 9, 16));
    });
  });

  test('7 Nov 2026 is the first week of هاتور', () {
    expect(
        programme.slotOn(DateTime(2026, 11, 7), start), const LessonSlot(3, 1));
    expect(
      programme.lessonOn(DateTime(2026, 11, 7), 3, firstDay: start)?.title,
      'هاتور الأول',
    );
    expect(
      programme.extrasOn(DateTime(2026, 11, 7), firstDay: start)?.pulpit,
      'منبر',
    );
  });

  test('the first session (24 Oct 2026) is the 7th lesson: بابة week 3', () {
    expect(programme.slotOn(DateTime(2026, 10, 24), start),
        const LessonSlot(2, 3));
  });

  test('every 4 weeks the next Coptic month starts', () {
    expect(programme.slotOn(DateTime(2026, 12, 5), start),
        const LessonSlot(4, 1)); // كيهك week 1
    expect(programme.slotOn(DateTime(2026, 11, 28), start),
        const LessonSlot(3, 4));
  });

  test('the 48th Saturday is the last lesson, then none', () {
    final last = start.add(const Duration(days: 7 * 47));
    expect(last, DateTime(2027, 8, 7));
    expect(programme.lessonOn(last, 3, firstDay: start)?.title, 'الأخير');
    expect(
      programme.lessonOn(last.add(const Duration(days: 7)), 3, firstDay: start),
      isNull,
    );
  });

  test('before the programme starts there is no lesson', () {
    expect(programme.slotOn(DateTime(2026, 9, 5), start), isNull);
  });

  group('breaks', () {
    // 7 Nov postponed, 28 Nov cancelled.
    final withBreaks = LessonProgramme(
      const [],
      const {},
      const {'2026-11-07': true, '2026-11-28': false},
    );

    test('a postponed week has no lesson and pushes the next ones back', () {
      expect(withBreaks.slotOn(DateTime(2026, 10, 31), start),
          const LessonSlot(2, 4)); // before the break: unchanged
      expect(withBreaks.slotOn(DateTime(2026, 11, 7), start), isNull);
      // the lesson that was for 7 Nov (هاتور week 1) moves to 14 Nov
      expect(withBreaks.slotOn(DateTime(2026, 11, 14), start),
          const LessonSlot(3, 1));
    });

    test('a cancelled week drops its lesson; later weeks do not move', () {
      // without the 7 Nov break 28 Nov would be هاتور 4; the postponed week
      // shifts everything by one, so it is هاتور 3 and 21 Nov is هاتور 2.
      expect(withBreaks.slotOn(DateTime(2026, 11, 21), start),
          const LessonSlot(3, 2));
      expect(withBreaks.slotOn(DateTime(2026, 11, 28), start), isNull);
      // the cancelled lesson (هاتور 3) is skipped: 5 Dec gets هاتور 4
      expect(withBreaks.slotOn(DateTime(2026, 12, 5), start),
          const LessonSlot(3, 4));
    });

    test('breakOn tells postponed, cancelled and normal weeks apart', () {
      expect(withBreaks.breakOn(DateTime(2026, 11, 7)), isTrue);
      expect(withBreaks.breakOn(DateTime(2026, 11, 28)), isFalse);
      expect(withBreaks.breakOn(DateTime(2026, 11, 14)), isNull);
    });
  });
}
