import '../../core/utils/app_date_utils.dart';
import '../../core/utils/app_failure.dart';
import '../models/badges.dart';
import '../supabase/db.dart';

/// The children's badges and class rankings, worked out by the database from
/// the attendance (child_badges, class_leaderboard). Row level security keeps
/// each servant to their own class.
class BadgeRepository {
  const BadgeRepository();

  Future<List<ChildBadge>> _badges(Map<String, dynamic> params) async {
    try {
      final data = await Db.client.rpc('child_badges', params: params);
      return [
        for (final r in rows(data))
          if (ChildBadge.fromMap(r) case final b?) b,
      ];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// One child's six badges.
  Future<List<ChildBadge>> forChild({
    required String yearId,
    required String childId,
  }) =>
      _badges({'p_year': yearId, 'p_child': childId});

  /// Every active child's badges in [classId].
  Future<List<ChildBadge>> forClass({
    required String yearId,
    required String classId,
  }) =>
      _badges({'p_year': yearId, 'p_class': classId});

  /// The class ranking, best first: the whole year, or from [from] on
  /// (the first of the month for «الشهر ده»).
  Future<List<LeaderboardRow>> leaderboard({
    required String yearId,
    required String classId,
    DateTime? from,
  }) async {
    try {
      final data = await Db.client.rpc('class_leaderboard', params: {
        'p_year': yearId,
        'p_class': classId,
        if (from != null) 'p_from': AppDateUtils.toIsoDate(from),
      });
      return rows(data).map(LeaderboardRow.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
