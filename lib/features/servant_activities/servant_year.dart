import '../../data/models/servant_activity.dart';
import 'servant_day_widgets.dart' show servantDayActivities;

/// The servants' badges, worked out from the year's marks and preps.
enum ServantBadge {
  /// «خادم أمين»: خدمة (and the prep, for a class servant) 4 Saturdays in a
  /// row.
  faithful(4),

  /// «تحضير متميّز»: 5 preps accepted.
  greatPrep(5),

  /// «اجتماع ثابت»: the servants' meeting every Saturday of a finished month
  /// (at least 3 Saturdays).
  meeting(1),

  /// «قلب نقي»: confession at least once a month, 3 months in a row.
  confession(3);

  const ServantBadge(this.target);

  /// What a servant has to reach.
  final int target;
}

/// One servant and one badge: earned or how far along.
class ServantBadgeState {
  const ServantBadgeState(this.badge,
      {required this.earned, this.progress = 0});

  final ServantBadge badge;
  final bool earned;
  final int progress;

  int get target => badge.target;
}

/// How many Saturdays have a prep: one the servant uploaded, or one the admin
/// ticked by hand («تحضير الدرس» in the servant's marks), counted once per
/// Saturday. Only [dates] (the Saturdays with a lesson, no إجازة / نشاط
/// ترفيهي) count; an empty [dates] (not loaded) leaves every date in.
int prepSaturdays({
  required Iterable<LessonPrep> preps,
  required Iterable<ServantAttendance> marks,
  Iterable<DateTime> dates = const [],
}) {
  String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  final allowed = {for (final d in dates) key(d)};
  bool ok(DateTime d) => allowed.isEmpty || allowed.contains(key(d));
  return {
    for (final p in preps)
      if (ok(p.sessionDate)) key(p.sessionDate),
    for (final m in marks)
      if (m.activityType == 'lesson_prep' && ok(m.date)) key(m.date),
  }.length;
}

/// Why a servant is on «محتاج متابعة».
enum ServantFollowUpReason { absent, preps }

class ServantFollowUp {
  const ServantFollowUp(this.servantId, this.reason, this.count);

  final String servantId;
  final ServantFollowUpReason reason;

  /// Saturdays missed in a row, or preps missed of the last three.
  final int count;
}

/// A year of servant activity, held in memory: which Saturdays were held,
/// who was marked for what on each, and who sent which prep. Everything the
/// follow-up card, the trends and the badges need, without more queries.
class ServantYear {
  ServantYear({
    required List<DateTime> heldSaturdays,
    required List<ServantAttendance> marks,
    required List<LessonPrep> preps,
    required this.today,
    Set<String> classServantIds = const {},
    Iterable<DateTime> noPrepDays = const [],
  })  : _classServants = classServantIds,
        _noPrep = {for (final d in noPrepDays) _key(_day(d))},
        held = (heldSaturdays
            .map(_day)
            .where((d) => !d.isAfter(_day(today)))
            .toSet()
            .toList()
          ..sort()),
        _marks = _index(marks),
        _preps = preps;

  /// Saturdays held up to [today], oldest first (no-lesson days excluded by
  /// the caller).
  final List<DateTime> held;
  final DateTime today;
  final Set<String> _classServants;

  /// Saturdays with no prep expected (a نشاط ترفيهي): the servant's marks
  /// count, a prep does not.
  final Set<String> _noPrep;
  final Map<String, Map<String, Set<String>>> _marks;
  final List<LessonPrep> _preps;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static Map<String, Map<String, Set<String>>> _index(
      List<ServantAttendance> marks) {
    final out = <String, Map<String, Set<String>>>{};
    for (final m in marks) {
      (out.putIfAbsent(m.servantId, () => {})[_key(m.date)] ??= {})
          .add(m.activityType);
    }
    return out;
  }

  Set<String> typesOn(String servantId, DateTime day) =>
      _marks[servantId]?[_key(day)] ?? const {};

  bool _anyActivity(String servantId, DateTime day) =>
      typesOn(servantId, day).any(servantDayActivities.contains);

  /// A prep for [day]: sent (any status) or ticked by hand.
  bool prepOn(String servantId, DateTime day) =>
      typesOn(servantId, day).contains('lesson_prep') ||
      _preps.any(
          (p) => p.servantId == servantId && _key(p.sessionDate) == _key(day));

  bool _expectsPrep(String servantId) => _classServants.contains(servantId);

  /// The latest held Saturdays in a row with none of the four activities.
  int absentRun(String servantId) {
    var run = 0;
    for (final d in held.reversed) {
      if (_anyActivity(servantId, d)) break;
      run++;
    }
    return run;
  }

  /// Of the last three held Saturdays, how many have no prep (class servants
  /// only; 0 for a general servant).
  int missedRecentPreps(String servantId) {
    if (!_expectsPrep(servantId)) return 0;
    final needing = [
      for (final d in held)
        if (!_noPrep.contains(_key(d))) d,
    ];
    final last =
        needing.length <= 3 ? needing : needing.sublist(needing.length - 3);
    return last.where((d) => !prepOn(servantId, d)).length;
  }

  /// Who needs a word: absent 2+ Saturdays in a row, or (class servants) 2 of
  /// the last 3 preps missing. Absence first, then the longest run.
  List<ServantFollowUp> followUps(Iterable<String> servantIds) {
    final out = <ServantFollowUp>[];
    for (final id in servantIds) {
      final absent = absentRun(id);
      if (absent >= 2) {
        out.add(ServantFollowUp(id, ServantFollowUpReason.absent, absent));
        continue;
      }
      final missed = missedRecentPreps(id);
      if (missed >= 2 && held.length >= 3) {
        out.add(ServantFollowUp(id, ServantFollowUpReason.preps, missed));
      }
    }
    out.sort((a, b) {
      if (a.reason != b.reason) return a.reason.index - b.reason.index;
      return b.count - a.count;
    });
    return out;
  }

  /// The four activities over the held Saturdays of [month]'s month: marks
  /// out of 4 × Saturdays, 0–100. Null with no Saturday that month.
  double? monthRate(String servantId, DateTime month) {
    final days = held
        .where((d) => d.year == month.year && d.month == month.month)
        .toList();
    if (days.isEmpty) return null;
    var marked = 0;
    for (final d in days) {
      marked +=
          typesOn(servantId, d).where(servantDayActivities.contains).length;
    }
    return marked / (days.length * servantDayActivities.length) * 100;
  }

  /// This month against last month, in points; null when either is unknown.
  double? trend(String servantId) {
    final now = DateTime(today.year, today.month);
    final before = DateTime(today.year, today.month - 1);
    final a = monthRate(servantId, now);
    final b = monthRate(servantId, before);
    if (a == null || b == null) return null;
    return a - b;
  }

  List<ServantBadgeState> badges(String servantId) => [
        _faithful(servantId),
        _greatPrep(servantId),
        _meeting(servantId),
        _confession(servantId),
      ];

  ServantBadgeState _faithful(String id) {
    var run = 0;
    var best = 0;
    for (final d in held) {
      final ok = typesOn(id, d).contains('sunday_school') &&
          (!_expectsPrep(id) || _noPrep.contains(_key(d)) || prepOn(id, d));
      run = ok ? run + 1 : 0;
      if (run > best) best = run;
    }
    final t = ServantBadge.faithful.target;
    return ServantBadgeState(ServantBadge.faithful,
        earned: best >= t, progress: run > t ? t : run);
  }

  ServantBadgeState _greatPrep(String id) {
    // Only Saturdays held: a prep for a no-lesson day (إجازة / نشاط ترفيهي)
    // is not in [held] and counts for nothing.
    final heldKeys = {
      for (final d in held)
        if (!_noPrep.contains(_key(d))) _key(d),
    };
    final accepted = _preps
        .where((p) =>
            p.servantId == id &&
            p.isAccepted &&
            heldKeys.contains(_key(p.sessionDate)))
        .map((p) => _key(p.sessionDate))
        .toSet()
        .length;
    final t = ServantBadge.greatPrep.target;
    return ServantBadgeState(ServantBadge.greatPrep,
        earned: accepted >= t, progress: accepted > t ? t : accepted);
  }

  /// Held Saturdays by month (first of the month), oldest first.
  Map<DateTime, List<DateTime>> get _months {
    final out = <DateTime, List<DateTime>>{};
    for (final d in held) {
      (out[DateTime(d.year, d.month)] ??= []).add(d);
    }
    return out;
  }

  ServantBadgeState _meeting(String id) {
    final thisMonth = DateTime(today.year, today.month);
    var earned = false;
    for (final MapEntry(key: m, value: days) in _months.entries) {
      if (!m.isBefore(thisMonth) || days.length < 3) continue;
      if (days.every((d) => typesOn(id, d).contains('servant_meeting'))) {
        earned = true;
        break;
      }
    }
    return ServantBadgeState(ServantBadge.meeting,
        earned: earned, progress: earned ? 1 : 0);
  }

  ServantBadgeState _confession(String id) {
    final t = ServantBadge.confession.target;
    var run = 0;
    var best = 0;
    for (final days in _months.values) {
      final confessed = days.any((d) => typesOn(id, d).contains('confession'));
      run = confessed ? run + 1 : 0;
      if (run > best) best = run;
    }
    return ServantBadgeState(ServantBadge.confession,
        earned: best >= t, progress: run > t ? t : run);
  }
}
