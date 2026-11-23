import 'parsers.dart';

/// The children's badges, as the database names them (child_badges).
/// The order is the order the grid shows them in.
enum KidBadge {
  streak4('streak4'),
  massMonth('mass_month'),
  fullDay('full_day'),
  confession3('confession3'),
  starMonth('star_month'),
  streak16('streak16');

  const KidBadge(this.id);

  final String id;

  static KidBadge? fromId(String id) {
    for (final b in values) {
      if (b.id == id) return b;
    }
    return null;
  }
}

/// One child and one badge: earned (and when) or how far along.
class ChildBadge {
  const ChildBadge({
    required this.childId,
    required this.classId,
    required this.badge,
    required this.progress,
    required this.target,
    this.earnedOn,
  });

  final String childId;
  final String classId;
  final KidBadge badge;
  final DateTime? earnedOn;
  final int progress;
  final int target;

  bool get earned => earnedOn != null;

  /// 0–1 for the progress bar of a badge still to earn.
  double get share =>
      target <= 0 ? 0 : (progress / target).clamp(0, 1).toDouble();

  /// Null for a badge name the app does not know (a newer database).
  static ChildBadge? fromMap(Map<String, dynamic> map) {
    final badge = KidBadge.fromId(asText(map['badge']));
    if (badge == null) return null;
    return ChildBadge(
      childId: asText(map['child_id']),
      classId: asText(map['class_id']),
      badge: badge,
      earnedOn: asDateOrNull(map['earned_on']),
      progress: asInt(map['progress']),
      target: asInt(map['target']),
    );
  }

  /// The badges earned on [day] exactly: the ones a save of that Saturday
  /// just won (for the «وسام جديد» moment).
  static List<ChildBadge> wonOn(Iterable<ChildBadge> badges, DateTime day) => [
        for (final b in badges)
          if (b.earnedOn != null &&
              b.earnedOn!.year == day.year &&
              b.earnedOn!.month == day.month &&
              b.earnedOn!.day == day.day)
            b,
      ];
}

/// Points a badge adds to the game points (not to the attendance reports).
const int kBadgeBonus = 10;


/// One line of a class's ranking.
class LeaderboardRow {
  const LeaderboardRow({
    required this.childId,
    required this.childName,
    required this.attendancePoints,
    required this.badgesEarned,
    required this.gamePoints,
  });

  final String childId;
  final String childName;
  final int attendancePoints;
  final int badgesEarned;

  /// Attendance points + [kBadgeBonus] per badge.
  final int gamePoints;

  factory LeaderboardRow.fromMap(Map<String, dynamic> map) => LeaderboardRow(
        childId: asText(map['child_id']),
        childName: asText(map['child_name']),
        attendancePoints: asInt(map['attendance_points']),
        badgesEarned: asInt(map['badges_earned']),
        gamePoints: asInt(map['game_points']),
      );

  /// 1-based place of [childId] in [rows] (already best first); ties share
  /// a place. Null when the child is not in the list.
  static int? rankOf(List<LeaderboardRow> rows, String childId) {
    int? rank;
    for (var i = 0; i < rows.length; i++) {
      if (i == 0 || rows[i].gamePoints != rows[i - 1].gamePoints) rank = i + 1;
      if (rows[i].childId == childId) return rank;
    }
    return null;
  }
}

/// The growth levels over a year's game points: بذرة, نبتة, شجرة, ثمرة.
enum GameLevel {
  seed(0),
  sprout(100),
  tree(300),
  fruit(600);

  const GameLevel(this.from);

  /// The game points this level starts at.
  final int from;

  static GameLevel of(int points) {
    var level = GameLevel.seed;
    for (final l in values) {
      if (points >= l.from) level = l;
    }
    return level;
  }

  /// The level after this one; null at the top.
  GameLevel? get next => index + 1 < values.length ? values[index + 1] : null;

  /// Points still needed for the next level (0 at the top).
  static int toNext(int points) {
    final n = of(points).next;
    return n == null ? 0 : n.from - points;
  }

  /// 0–1 along the way to the next level (1 at the top).
  static double progress(int points) {
    final l = of(points);
    final n = l.next;
    if (n == null) return 1;
    return ((points - l.from) / (n.from - l.from)).clamp(0, 1).toDouble();
  }
}
