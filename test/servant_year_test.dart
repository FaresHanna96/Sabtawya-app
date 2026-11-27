import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/servant_activity.dart';
import 'package:sabtawya/features/servant_activities/servant_year.dart';

ServantAttendance _m(String servant, String type, DateTime d) =>
    ServantAttendance.fromMap({
      'id': '$servant-$type-${d.toIso8601String()}',
      'servant_id': servant,
      'activity_type': type,
      'date': d.toIso8601String().substring(0, 10),
      'recorded_by': 'admin',
    });

LessonPrep _p(String servant, DateTime d, {String status = 'pending'}) =>
    LessonPrep.fromMap({
      'id': 'p-$servant-${d.day}-${d.month}',
      'servant_id': servant,
      'session_id': 's',
      'status': status,
      'attendance_sessions': {
        'session_date': d.toIso8601String().substring(0, 10)
      },
    });

/// Saturdays Oct 3 – Nov 21 2026 (8 of them).
final _sats = [
  for (var d = DateTime(2026, 10, 3);
      !d.isAfter(DateTime(2026, 11, 21));
      d = d.add(const Duration(days: 7)))
    d,
];

final _today = DateTime(2026, 11, 23);

ServantYear _year({
  List<ServantAttendance> marks = const [],
  List<LessonPrep> preps = const [],
  Set<String> classServants = const {'a'},
}) =>
    ServantYear(
      heldSaturdays: [..._sats, DateTime(2026, 12, 5)], // a future one
      marks: marks,
      preps: preps,
      today: _today,
      classServantIds: classServants,
    );

void main() {
  test('future Saturdays are not held yet', () {
    expect(_year().held, hasLength(8));
  });

  group('absentRun', () {
    test('counts the latest Saturdays with nothing marked', () {
      final y = _year(marks: [_m('a', 'mass', _sats[5])]);
      expect(y.absentRun('a'), 2);
    });
    test('a prep alone is not attendance', () {
      final y = _year(marks: [_m('a', 'lesson_prep', _sats[7])]);
      expect(y.absentRun('a'), 8);
    });
  });

  group('trend', () {
    test('this month against last, in points', () {
      // October: 1 of 4 activities on each of 5 Saturdays = 25%.
      // November: 2 of 4 on each of 3 Saturdays = 50%.
      final y = _year(marks: [
        for (final d in _sats.where((d) => d.month == 10))
          _m('a', 'sunday_school', d),
        for (final d in _sats.where((d) => d.month == 11)) ...[
          _m('a', 'sunday_school', d),
          _m('a', 'mass', d),
        ],
      ]);
      expect(y.monthRate('a', DateTime(2026, 10)), 25);
      expect(y.monthRate('a', DateTime(2026, 11)), 50);
      expect(y.trend('a'), 25);
    });
    test('no Saturday in a month: unknown', () {
      expect(_year().monthRate('a', DateTime(2026, 8)), isNull);
    });
  });

  group('badges', () {
    ServantBadgeState badge(ServantYear y, ServantBadge b) =>
        y.badges('a').firstWhere((s) => s.badge == b);

    test('خادم أمين: خدمة + prep 4 in a row', () {
      final y = _year(marks: [
        for (final d in _sats.sublist(2, 6)) _m('a', 'sunday_school', d),
      ], preps: [
        for (final d in _sats.sublist(2, 6)) _p('a', d),
      ]);
      expect(badge(y, ServantBadge.faithful).earned, isTrue);
    });

    test('خادم أمين: a week without the prep breaks the run', () {
      final y = _year(marks: [
        for (final d in _sats.sublist(4)) _m('a', 'sunday_school', d),
      ], preps: [
        for (final d in _sats.sublist(4))
          if (d != _sats[6]) _p('a', d),
      ]);
      final s = badge(y, ServantBadge.faithful);
      expect(s.earned, isFalse);
      expect(s.progress, 1);
    });

    test('تحضير متميّز: 5 accepted', () {
      final y = _year(preps: [
        for (final d in _sats.take(5)) _p('a', d, status: 'accepted'),
        _p('a', _sats[6]),
      ]);
      expect(badge(y, ServantBadge.greatPrep).earned, isTrue);
    });

    test('تحضير متميّز: a prep on a no-lesson Saturday does not count', () {
      // _sats[0] was marked إجازة: it is not among the held Saturdays.
      final held = _sats.skip(1).toList();
      final y = ServantYear(
        heldSaturdays: held,
        marks: const [],
        preps: [
          for (final d in _sats.take(5)) _p('a', d, status: 'accepted'),
        ],
        today: DateTime(2026, 11, 22),
      );
      final b = badge(y, ServantBadge.greatPrep);
      expect(b.earned, isFalse);
      expect(b.progress, 4);
    });

    test('اجتماع ثابت: every Saturday of a finished month', () {
      final y = _year(marks: [
        for (final d in _sats.where((d) => d.month == 10))
          _m('a', 'servant_meeting', d),
      ]);
      expect(badge(y, ServantBadge.meeting).earned, isTrue);
    });

    test('اجتماع ثابت: the month still running does not count', () {
      final y = _year(marks: [
        for (final d in _sats.where((d) => d.month == 11))
          _m('a', 'servant_meeting', d),
      ]);
      expect(badge(y, ServantBadge.meeting).earned, isFalse);
    });

    test('قلب نقي: needs three months in a row', () {
      final y = _year(marks: [
        _m('a', 'confession', _sats[0]),
        _m('a', 'confession', _sats[6]),
      ]);
      final s = badge(y, ServantBadge.confession);
      expect(s.earned, isFalse);
      expect(s.progress, 2);
    });
  });

  group('prepSaturdays', () {
    test('an admin-ticked prep counts like an uploaded one', () {
      final n = prepSaturdays(
        preps: [_p('a', _sats[0])],
        marks: [_m('a', 'lesson_prep', _sats[1])],
        dates: _sats,
      );
      expect(n, 2);
    });

    test('uploaded and ticked on the same Saturday is one', () {
      final n = prepSaturdays(
        preps: [_p('a', _sats[0])],
        marks: [_m('a', 'lesson_prep', _sats[0])],
        dates: _sats,
      );
      expect(n, 1);
    });

    test('other marks are not preps', () {
      final n = prepSaturdays(
        preps: const [],
        marks: [_m('a', 'mass', _sats[0])],
        dates: _sats,
      );
      expect(n, 0);
    });

    test('a no-lesson Saturday (not in dates) counts for nothing', () {
      final n = prepSaturdays(
        preps: [_p('a', _sats[0])],
        marks: [_m('a', 'lesson_prep', _sats[0]), _m('a', 'lesson_prep', _sats[1])],
        dates: _sats.skip(1),
      );
      expect(n, 1);
    });
  });

  group('a نشاط ترفيهي day (no prep expected)', () {
    // _sats[3] is a نشاط ترفيهي: servants are marked, nobody sends a prep.
    ServantYear withActivity({
      List<ServantAttendance> marks = const [],
      List<LessonPrep> preps = const [],
    }) =>
        ServantYear(
          heldSaturdays: _sats,
          marks: marks,
          preps: preps,
          today: _today,
          classServantIds: const {'a'},
          noPrepDays: [_sats[3]],
        );

    test('خادم أمين: the streak is not broken by the missing prep', () {
      final y = withActivity(
        marks: [
          for (final d in _sats.take(5)) _m('a', 'sunday_school', d),
        ],
        preps: [
          for (final d in _sats.take(5))
            if (d != _sats[3]) _p('a', d),
        ],
      );
      final b = y.badges('a').firstWhere((s) => s.badge == ServantBadge.faithful);
      expect(b.earned, isTrue);
    });

    test('without the exemption the same week breaks the streak', () {
      final y = _year(
        marks: [
          for (final d in _sats.take(5)) _m('a', 'sunday_school', d),
        ],
        preps: [
          for (final d in _sats.take(5))
            if (d != _sats[3]) _p('a', d),
        ],
      );
      final b = y.badges('a').firstWhere((s) => s.badge == ServantBadge.faithful);
      expect(b.earned, isFalse);
    });

    test('تحضير متميّز: a prep on that day does not count', () {
      final y = withActivity(preps: [
        for (final d in _sats.take(5)) _p('a', d, status: 'accepted'),
      ]);
      final b =
          y.badges('a').firstWhere((s) => s.badge == ServantBadge.greatPrep);
      expect(b.progress, 4);
      expect(b.earned, isFalse);
    });

    test('the servant marks still count on that day', () {
      final y = withActivity(marks: [_m('a', 'mass', _sats[3])]);
      expect(y.typesOn('a', _sats[3]), contains('mass'));
      expect(y.held, contains(_sats[3]));
    });
  });
}
