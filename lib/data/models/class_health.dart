import 'parsers.dart';

/// How a class is doing, worst first.
enum HealthLevel { red, amber, green }

/// What a reason is about (the card shows an icon for each).
enum HealthArea { servants, attendance, late, prep, followUp, presence }

/// One thing that brought a class down, and how much.
class HealthReason {
  const HealthReason(this.level, this.text, this.area);

  final HealthLevel level;
  final String text;
  final HealthArea area;
}

/// A row of `class_health`: one active class over the year so far.
class ClassHealth {
  const ClassHealth({
    required this.classId,
    required this.className,
    required this.servantsCount,
    required this.activeChildren,
    required this.held,
    required this.taken,
    required this.takenLate,
    required this.prepExpected,
    required this.prepSubmitted,
    required this.prepAccepted,
    required this.absent2plus,
    required this.absentFollowed,
    this.presentPct,
  });

  final String classId;
  final String className;
  final int servantsCount;
  final int activeChildren;

  /// Saturdays counted so far (a no-lesson Saturday with nothing recorded is
  /// left out).
  final int held;

  /// Saturdays with attendance recorded.
  final int taken;

  /// Of [taken], recorded more than a day after the Saturday.
  final int takenLate;

  /// Present over marked, 0-100; null before any mark.
  final double? presentPct;
  final int prepExpected;
  final int prepSubmitted;
  final int prepAccepted;

  /// Children absent the last two Saturdays or more.
  final int absent2plus;

  /// Of [absent2plus], called or visited since they last came.
  final int absentFollowed;

  int get absentNotFollowed =>
      (absent2plus - absentFollowed).clamp(0, absent2plus);

  /// Preps sent over preps expected, 0-100; null when none were expected.
  int? get prepPct => prepExpected == 0
      ? null
      : (100 * prepSubmitted / prepExpected).round().clamp(0, 100);

  factory ClassHealth.fromMap(Map<String, dynamic> map) => ClassHealth(
        classId: asText(map['class_id']),
        className: asText(map['class_name']),
        servantsCount: asInt(map['servants_count']),
        activeChildren: asInt(map['active_children']),
        held: asInt(map['held']),
        taken: asInt(map['taken']),
        takenLate: asInt(map['taken_late']),
        presentPct:
            map['present_pct'] == null ? null : asDouble(map['present_pct']),
        prepExpected: asInt(map['prep_expected']),
        prepSubmitted: asInt(map['prep_submitted']),
        prepAccepted: asInt(map['prep_accepted']),
        absent2plus: asInt(map['absent_2plus']),
        absentFollowed: asInt(map['absent_followed']),
      );

  // ── Thresholds: the one place that decides red / amber ────────────────────

  /// Share of Saturdays with attendance recorded.
  static const takenRed = 0.75, takenAmber = 0.9;

  /// Share of recorded Saturdays saved more than a day late.
  static const lateAmber = 0.3;

  /// Share of the expected preps that were sent.
  static const prepRed = 0.4, prepAmber = 0.7;

  /// Absent children nobody called or visited.
  static const unfollowedRed = 3, unfollowedAmber = 1;

  /// Present over marked, in percent.
  static const presentAmber = 50.0;

  /// Why the class is not green, worst first; empty when all is well.
  List<HealthReason> get reasons {
    final out = <HealthReason>[];
    if (servantsCount == 0) {
      out.add(const HealthReason(
          HealthLevel.red, 'الفصل محتاج خادم', HealthArea.servants));
    }
    if (held > 0) {
      final share = taken / held;
      if (share < takenAmber) {
        out.add(HealthReason(
          share < takenRed ? HealthLevel.red : HealthLevel.amber,
          'الحضور اتسجّل في $taken من $held ${held <= 10 ? 'سبوت' : 'سبت'}',
          HealthArea.attendance,
        ));
      }
    }
    if (taken > 0 && takenLate / taken > lateAmber) {
      out.add(HealthReason(
        HealthLevel.amber,
        'الحضور اتسجّل متأخر $takenLate ${takenLate == 1 ? 'مرة' : 'مرات'}',
        HealthArea.late,
      ));
    }
    if (prepExpected > 0) {
      final share = prepSubmitted / prepExpected;
      if (share < prepAmber) {
        out.add(HealthReason(
          share < prepRed ? HealthLevel.red : HealthLevel.amber,
          'التحضير اترفع ${prepPct ?? 0}%',
          HealthArea.prep,
        ));
      }
    }
    final unfollowed = absentNotFollowed;
    if (unfollowed >= unfollowedAmber) {
      out.add(HealthReason(
        unfollowed >= unfollowedRed ? HealthLevel.red : HealthLevel.amber,
        unfollowed == 1
            ? 'طفل غايب من غير افتقاد'
            : '$unfollowed ${unfollowed <= 10 ? 'أطفال غايبين' : 'طفل غايب'} من غير افتقاد',
        HealthArea.followUp,
      ));
    }
    final pct = presentPct;
    if (pct != null && pct < presentAmber) {
      out.add(HealthReason(
        HealthLevel.amber,
        'نسبة الحضور ${pct.toStringAsFixed(0)}%',
        HealthArea.presence,
      ));
    }
    out.sort((a, b) => a.level.index.compareTo(b.level.index));
    return out;
  }

  /// A share in 0..1 for the detail bars; null when there is nothing to
  /// measure yet.
  static double? share(int part, int whole) =>
      whole <= 0 ? null : (part / whole).clamp(0.0, 1.0);

  HealthLevel get level =>
      reasons.isEmpty ? HealthLevel.green : reasons.first.level;

  /// Worst class first, then by name.
  static int byConcern(ClassHealth a, ClassHealth b) {
    final l = a.level.index.compareTo(b.level.index);
    if (l != 0) return l;
    final n = b.reasons.length.compareTo(a.reasons.length);
    return n != 0 ? n : a.className.compareTo(b.className);
  }
}
