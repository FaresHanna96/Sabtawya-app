import '../../core/utils/app_date_utils.dart';
import '../../core/utils/app_failure.dart';
import '../models/badges.dart';
import '../models/reports.dart';
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

  /// Every active child's badges in the whole school (an admin or a
  /// general servant sees them all; a servant only their class).
  Future<List<ChildBadge>> forSchool({required String yearId}) =>
      _badges({'p_year': yearId});

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

/// The طايو the badges add on top of the attendance points: [kBadgeBonus]
/// for each badge earned, counted on the day it was earned. Every place that
/// shows a child's طايو adds this to the attendance points.
class BadgeBonus {
  const BadgeBonus._(this._dates);

  /// No bonus: used when the badges could not be read.
  static const none = BadgeBonus._(<String, List<DateTime>>{});

  /// childId -> the days their badges were earned.
  final Map<String, List<DateTime>> _dates;

  factory BadgeBonus.of(Iterable<ChildBadge> badges) {
    final dates = <String, List<DateTime>>{};
    for (final b in badges) {
      final on = b.earnedOn;
      if (on == null) continue;
      (dates[b.childId] ??= []).add(AppDateUtils.dateOnly(on));
    }
    return BadgeBonus._(dates);
  }

  /// The badges of every child in [classIds] for the year. A class that
  /// cannot be read simply adds nothing.
  static Future<BadgeBonus> load({
    required String yearId,
    required Iterable<String> classIds,
  }) async {
    const repository = BadgeRepository();
    final lists = await Future.wait([
      for (final id in classIds.toSet())
        repository
            .forClass(yearId: yearId, classId: id)
            .catchError((Object _) => const <ChildBadge>[]),
    ]);
    return BadgeBonus.of(lists.expand((l) => l));
  }

  /// The bonus earned between [from] and [to] (either may be open, both
  /// inclusive); the whole year when both are null.
  int between(String childId, {DateTime? from, DateTime? to}) {
    final f = from == null ? null : AppDateUtils.dateOnly(from);
    final t = to == null ? null : AppDateUtils.dateOnly(to);
    var n = 0;
    for (final d in _dates[childId] ?? const <DateTime>[]) {
      if (f != null && d.isBefore(f)) continue;
      if (t != null && d.isAfter(t)) continue;
      n++;
    }
    return n * kBadgeBonus;
  }

  int year(String childId) => between(childId);

  /// The bonus earned in the month starting [monthStart].
  int inMonth(String childId, DateTime monthStart) => between(
        childId,
        from: DateTime(monthStart.year, monthStart.month),
        to: DateTime(monthStart.year, monthStart.month + 1, 0),
      );

  ChildYearReport forYear(ChildYearReport r) => r.withBonus(year(r.childId));

  ChildMonthlyReport forMonth(ChildMonthlyReport r) =>
      r.withBonus(inMonth(r.childId, r.monthStart));
}
