import '../../core/utils/app_failure.dart';
import '../../core/utils/arabic_sort.dart';
import '../models/competition.dart';
import '../supabase/db.dart';

class CompetitionRepository {
  const CompetitionRepository();

  Future<List<Competition>> listCompetitions() async {
    try {
      final data = await Db.client
          .from(Db.tCompetitions)
          .select()
          .order('week_date', ascending: false);
      return rows(data).map(Competition.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Competition> createCompetition({
    required String title,
    required DateTime weekDate,
    int maxMark = 10,
    String? yearId,
  }) async {
    try {
      final userId = Db.userId;
      if (userId == null) throw AppFailure('لم يتم التحقق من الهوية');
      final data = await Db.client
          .from(Db.tCompetitions)
          .insert({
            'title': title.trim(),
            'week_date': weekDate.toIso8601String().split('T').first,
            'max_mark': maxMark,
            if (yearId != null) 'year_id': yearId,
            'created_by': userId,
          })
          .select()
          .single();
      return Competition.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Competition> updateCompetition(
    String id, {
    String? title,
    DateTime? weekDate,
    int? maxMark,
  }) async {
    try {
      final patch = <String, dynamic>{
        if (title != null) 'title': title.trim(),
        if (weekDate != null)
          'week_date': weekDate.toIso8601String().split('T').first,
        if (maxMark != null) 'max_mark': maxMark,
      };
      final data = await Db.client
          .from(Db.tCompetitions)
          .update(patch)
          .eq('id', id)
          .select()
          .single();
      return Competition.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> deleteCompetition(String id) async {
    try {
      await Db.client.from(Db.tCompetitions).delete().eq('id', id);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Returns rows with child info joined: {id, full_name, class_id, mark?}
  Future<List<Map<String, dynamic>>> childrenWithMarks(
      String competitionId) async {
    try {
      // Fetch all children the caller may see (RLS limits to assigned classes for servants)
      final childrenData = await Db.client
          .from(Db.tChildren)
          .select('id, full_name, class_id')
          .eq('is_active', true)
          .order('full_name');

      // Fetch existing marks for this competition
      final marksData = await Db.client
          .from(Db.tCompetitionMarks)
          .select('child_id, mark, id')
          .eq('competition_id', competitionId);

      final marksByChild = <String, Map<String, dynamic>>{
        for (final m in rows(marksData)) m['child_id'] as String: m,
      };

      final children = rows(childrenData)
        ..sort((a, b) => ArabicSort.compare(
            a['full_name'].toString(), b['full_name'].toString()));

      return children.map((child) {
        final existing = marksByChild[child['id'] as String];
        return {
          ...child,
          'mark': existing?['mark'],
          'mark_id': existing?['id'],
        };
      }).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> upsertMark(
      String competitionId, String childId, int mark) async {
    try {
      final userId = Db.userId;
      if (userId == null) throw AppFailure('لم يتم التحقق من الهوية');
      await Db.client.from(Db.tCompetitionMarks).upsert(
        {
          'competition_id': competitionId,
          'child_id': childId,
          'mark': mark,
          'marked_by': userId,
          'marked_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'competition_id,child_id',
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> deleteMark(String competitionId, String childId) async {
    try {
      await Db.client
          .from(Db.tCompetitionMarks)
          .delete()
          .eq('competition_id', competitionId)
          .eq('child_id', childId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Every mark of the given competitions, paged so more than 1000 rows work.
  Future<List<CompetitionMark>> marksFor(List<String> competitionIds) async {
    if (competitionIds.isEmpty) return const [];
    try {
      final result = <CompetitionMark>[];
      const page = 1000;
      for (var from = 0;; from += page) {
        final data = await Db.client
            .from(Db.tCompetitionMarks)
            .select()
            .inFilter('competition_id', competitionIds)
            .order('id')
            .range(from, from + page - 1);
        final batch = rows(data);
        result.addAll(batch.map(CompetitionMark.fromMap));
        if (batch.length < page) break;
      }
      return result;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<ChildCompetitionScore>> cumulativeScores({
    String? classId,
  }) async {
    try {
      var query = Db.client.from(Db.vChildCompScores).select();
      if (classId != null) query = query.eq('class_id', classId);
      final data = await query.order('total_marks', ascending: false);
      return rows(data).map(ChildCompetitionScore.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
