import '../../core/utils/app_failure.dart';
import '../models/lesson.dart';
import '../models/parsers.dart';
import '../supabase/db.dart';

/// The weekly lesson programme. It is small and static, so it is read whole;
/// the offline layer keeps the last copy for use without a connection.
class LessonRepository {
  const LessonRepository();

  Future<LessonProgramme> programme() async {
    try {
      final lessons = rows(await Db.client
              .from(Db.tLessons)
              .select()
              .order('coptic_month')
              .order('week'))
          .map(Lesson.fromMap)
          .toList();
      final extras = <LessonSlot, LessonExtras>{
        for (final row in rows(await Db.client.from(Db.tLessonExtras).select()))
          LessonSlot(row['coptic_month'] as int, row['week'] as int):
              LessonExtras.fromMap(row),
      };
      final breaks = <String, bool>{
        for (final row in rows(await Db.client.from(Db.tLessonBreaks).select()))
          asText(row['break_date']): asBool(row['shift'], true),
      };
      return LessonProgramme(lessons, extras, breaks);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// أمين الخدمة: corrects a lesson's title and page for one grade.
  Future<void> updateLesson({
    required LessonSlot slot,
    required int grade,
    required String title,
    int? page,
  }) async {
    try {
      await Db.client
          .from(Db.tLessons)
          .update(<String, dynamic>{'title': title.trim(), 'page': page})
          .eq('coptic_month', slot.month)
          .eq('week', slot.week)
          .eq('grade', grade);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// أمين الخدمة: sets the pulpit and hymns shared by every grade that week.
  Future<void> saveExtras({
    required LessonSlot slot,
    String? pulpit,
    String? hymns,
  }) async {
    String? blank(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();
    try {
      await Db.client.from(Db.tLessonExtras).upsert(<String, dynamic>{
        'coptic_month': slot.month,
        'week': slot.week,
        'pulpit': blank(pulpit),
        'hymns': blank(hymns),
      }, onConflict: 'coptic_month,week');
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// أمين الخدمة: no lesson on [saturday]. [shift] postpones it (later lessons
  /// move a week); otherwise it is cancelled (later lessons keep their dates).
  Future<void> setBreak(DateTime saturday, {required bool shift}) async {
    try {
      await Db.client.from(Db.tLessonBreaks).upsert(<String, dynamic>{
        'break_date': LessonProgramme.keyOf(saturday),
        'shift': shift,
      }, onConflict: 'break_date');
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Puts the lesson back on [saturday].
  Future<void> clearBreak(DateTime saturday) async {
    try {
      await Db.client
          .from(Db.tLessonBreaks)
          .delete()
          .eq('break_date', LessonProgramme.keyOf(saturday));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
