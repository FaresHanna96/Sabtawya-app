import 'package:image_picker/image_picker.dart';

import '../../core/utils/app_failure.dart';
import '../models/lesson.dart';

// The break types live with the programme; callers keep importing them from here.
export '../models/lesson.dart' show LessonBreak, LessonBreakKind;
import '../models/parsers.dart';
import '../services/photo_service.dart';
import '../supabase/db.dart';

/// The weekly lesson programme. It is small and static, so it is read whole;
/// the offline layer keeps the last copy for use without a connection.
class LessonRepository {
  const LessonRepository();

  Future<LessonProgramme> programme() async {
    try {
      final lessons = rows(await Db.from(Db.tLessons)
              .select()
              .order('coptic_month')
              .order('week'))
          .map(Lesson.fromMap)
          .toList();
      final extras = <LessonSlot, LessonExtras>{
        for (final row in rows(await Db.from(Db.tLessonExtras).select()))
          LessonSlot(row['coptic_month'] as int, row['week'] as int):
              LessonExtras.fromMap(row),
      };
      final found = await breaks();
      return LessonProgramme(
        lessons,
        extras,
        {for (final e in found.entries) e.key: e.value.shift},
        {for (final e in found.entries) e.key: e.value.kind},
        {
          for (final e in found.entries)
            if (e.value.attendanceTaken) e.key,
        },
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The programme's month and week of the lesson [id], or null when gone.
  Future<LessonSlot?> slotOfLesson(String id) async {
    try {
      final row = await Db.from(Db.tLessons)
          .select('coptic_month, week')
          .eq('id', id)
          .maybeSingle();
      return row == null
          ? null
          : LessonSlot(asInt(row['coptic_month']), asInt(row['week']));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The Saturdays with no lesson, by yyyy-MM-dd: why (a holiday or a نشاط
  /// ترفيهي) and whether the later lessons move a week. Attendance is not
  /// taken on them.
  Future<Map<String, LessonBreak>> breaks() async {
    try {
      List<Map<String, dynamic>> data;
      try {
        data = rows(await Db.from(Db.tLessonBreaks)
            .select('break_date, shift, kind, attendance_taken'));
      } catch (_) {
        try {
          // A database from before «الحضور بيتحسب»: no day takes attendance.
          data = rows(await Db.from(Db.tLessonBreaks)
              .select('break_date, shift, kind'));
        } catch (_) {
          // A database from before the kind column: every break a holiday.
          data = rows(await Db.from(Db.tLessonBreaks)
              .select('break_date, shift'));
        }
      }
      return {
        for (final row in data)
          asText(row['break_date']): LessonBreak(
            kind: LessonBreakKind.fromWire(row['kind']),
            shift: asBool(row['shift'], true),
            attendanceTaken: asBool(row['attendance_taken']),
          ),
      };
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Whether [iso] (yyyy-MM-dd) is out of the children's numbers: a break
  /// that is not a نشاط ترفيهي with attendance taken.
  static bool childrenOff(Map<String, LessonBreak> breaks, String iso) =>
      breaks[iso]?.excludesChildren ?? false;

  /// أمين الخدمة: corrects a lesson's title and page for one grade.
  Future<void> updateLesson({
    required LessonSlot slot,
    required int grade,
    required String title,
    int? page,
  }) async {
    try {
      await Db.from(Db.tLessons)
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
      await Db.from(Db.tLessonExtras).upsert(<String, dynamic>{
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
  Future<void> setBreak(
    DateTime saturday, {
    required bool shift,
    LessonBreakKind? kind,
    bool attendanceTaken = false,
  }) async {
    try {
      await Db.from(Db.tLessonBreaks).upsert(<String, dynamic>{
        'break_date': LessonProgramme.keyOf(saturday),
        'shift': shift,
        if (kind != null) 'kind': kind.wire,
        // Only a نشاط ترفيهي can take attendance.
        'attendance_taken':
            attendanceTaken && kind == LessonBreakKind.activity,
      }, onConflict: 'break_date');
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Puts the lesson back on [saturday].
  Future<void> clearBreak(DateTime saturday) async {
    try {
      await Db.from(Db.tLessonBreaks)
          .delete()
          .eq('break_date', LessonProgramme.keyOf(saturday));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  // ── Materials ──────────────────────────────────────────────────────────────

  /// The materials of [slot] for [grade], plus those for every grade.
  Future<List<LessonMaterial>> materials(LessonSlot slot, int grade) async {
    try {
      final data = await Db.from(Db.tLessonMaterials)
          .select()
          .eq('coptic_month', slot.month)
          .eq('week', slot.week)
          .or('grade.is.null,grade.eq.$grade')
          .order('created_at');
      return rows(data).map(LessonMaterial.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// أمين الخدمة: a web link (a video, a Drive folder) for the lesson.
  Future<void> addLink({
    required LessonSlot slot,
    required int? grade,
    required String title,
    required String url,
  }) async {
    try {
      await Db.from(Db.tLessonMaterials).insert(<String, dynamic>{
        'coptic_month': slot.month,
        'week': slot.week,
        'grade': grade,
        'kind': 'link',
        'title': title.trim(),
        'url': url.trim(),
      });
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// أمين الخدمة: a PDF or a picture for the lesson.
  Future<void> addFile({
    required LessonSlot slot,
    required int? grade,
    required String title,
    required XFile file,
  }) async {
    final path = await PhotoService.upload(
      bucket: Db.bucketLessonMaterials,
      ownerId: 'm${slot.month}-w${slot.week}',
      file: file,
    );
    try {
      await Db.from(Db.tLessonMaterials).insert(<String, dynamic>{
        'coptic_month': slot.month,
        'week': slot.week,
        'grade': grade,
        'kind': 'file',
        'title': title.trim(),
        'storage_path': path,
        'mime': path.toLowerCase().endsWith('.pdf')
            ? 'application/pdf'
            : 'image/${path.split('.').last}',
      });
    } catch (e) {
      // Do not leave a file nobody can see.
      try {
        await PhotoService.remove(
            bucket: Db.bucketLessonMaterials, path: path);
      } catch (_) {}
      throw AppFailure.from(e);
    }
  }

  Future<void> deleteMaterial(LessonMaterial m) async {
    try {
      await Db.from(Db.tLessonMaterials).delete().eq('id', m.id);
      if (m.storagePath != null) {
        await PhotoService.remove(
            bucket: Db.bucketLessonMaterials, path: m.storagePath);
      }
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  // ── Shared preps ───────────────────────────────────────────────────────────

  Future<List<SharedPrep>> sharedPreps(LessonSlot slot, int grade) async {
    try {
      final data = await Db.client.rpc('shared_preps', params: {
        'p_month': slot.month,
        'p_week': slot.week,
        'p_grade': grade,
      });
      return rows(data).map(SharedPrep.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// أمين الخدمة: shows an accepted prep to the servants of [grade] under the
  /// lesson of [slot].
  Future<void> sharePrep(String prepId, LessonSlot slot, int grade) async {
    try {
      await Db.client.rpc('share_prep', params: {
        'p_prep': prepId,
        'p_month': slot.month,
        'p_week': slot.week,
        'p_grade': grade,
      });
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> unsharePrep(String prepId) async {
    try {
      await Db.client.rpc('unshare_prep', params: {'p_prep': prepId});
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
