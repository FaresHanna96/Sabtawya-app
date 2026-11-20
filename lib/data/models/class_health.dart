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
    this.attendancePct,
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

  /// The class's attendance as the reports and "أداء الفصول" counted it:
  /// Saturdays the children came over Saturdays held, 0-100. Joined in from
  /// the class year scores; the health score prefers it to [presentPct].
  final double? attendancePct;

  /// This class with [pct] as its [attendancePct].
  ClassHealth withAttendance(double? pct) => ClassHealth(
        classId: classId,
        className: className,
        servantsCount: servantsCount,
        activeChildren: activeChildren,
        held: held,
        taken: taken,
        takenLate: takenLate,
        prepExpected: prepExpected,
        prepSubmitted: prepSubmitted,
        prepAccepted: prepAccepted,
        absent2plus: absent2plus,
        absentFollowed: absentFollowed,
        presentPct: presentPct,
        attendancePct: pct,
      );

  /// The children's attendance used by the score and shown in the card.
  double? get childrenAttendance => attendancePct ?? presentPct;
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
    final pct = childrenAttendance;
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

  // ── The health score ──────────────────────────────────────────────────────

  /// How much each part counts. The children coming is what the service is
  /// for, so it weighs most; the servants' work behind it shares the rest.
  static const wAttendance = 40, wTaken = 20, wPrep = 20, wFollowUp = 20;

  /// Score at or above which a class is green / amber (else red).
  static const scoreGreen = 75, scoreAmber = 50;

  /// 0-100, from the parts that can be measured so far (a part with nothing
  /// to measure yet, e.g. no prep expected, is left out and the rest
  /// re-weighed). Null before anything can be measured.
  int? get score {
    var total = 0.0;
    var weight = 0;
    void add(double? share, int w) {
      if (share == null) return;
      total += share.clamp(0.0, 1.0) * w;
      weight += w;
    }

    final att = childrenAttendance;
    add(att == null ? null : att / 100, wAttendance);
    add(share(taken, held), wTaken);
    add(share(prepSubmitted, prepExpected), wPrep);
    // Nobody absent twice in a row: nothing left to follow up.
    add(
        absent2plus == 0
            ? (held > 0 ? 1.0 : null)
            : absentFollowed / absent2plus,
        wFollowUp);
    if (weight == 0) return null;
    return (100 * total / weight).round();
  }

  /// Green / amber / red from the [score]; a class with no servant is red
  /// whatever its numbers.
  HealthLevel get level {
    if (servantsCount == 0) return HealthLevel.red;
    final s = score;
    if (s == null || s >= scoreGreen) return HealthLevel.green;
    return s >= scoreAmber ? HealthLevel.amber : HealthLevel.red;
  }

  /// Lowest score first (no score last), then by name.
  static int byConcern(ClassHealth a, ClassHealth b) {
    final sa = a.servantsCount == 0 ? -1 : (a.score ?? 101);
    final sb = b.servantsCount == 0 ? -1 : (b.score ?? 101);
    final c = sa.compareTo(sb);
    return c != 0 ? c : a.className.compareTo(b.className);
  }

  /// [classes] with the attendance % of [byClass] (class id → percent).
  static List<ClassHealth> joinAttendance(
    List<ClassHealth> classes,
    Map<String, double> byClass,
  ) =>
      [for (final c in classes) c.withAttendance(byClass[c.classId])];
}
