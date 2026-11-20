import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/class_health.dart';

ClassHealth health({
  String name = '5 ولاد',
  int servants = 2,
  int held = 10,
  int taken = 10,
  int late = 0,
  double? present = 80,
  int prepExpected = 20,
  int prepSubmitted = 20,
  int absent = 0,
  int followed = 0,
}) =>
    ClassHealth(
      classId: name,
      className: name,
      servantsCount: servants,
      activeChildren: 20,
      held: held,
      taken: taken,
      takenLate: late,
      presentPct: present,
      prepExpected: prepExpected,
      prepSubmitted: prepSubmitted,
      prepAccepted: prepSubmitted,
      absent2plus: absent,
      absentFollowed: followed,
    );

void main() {
  group('score', () {
    test('a class doing well scores high and is green', () {
      // 80% attendance (x40) + everything else full (3 x 20).
      final h = health();
      expect(h.score, 92);
      expect(h.level, HealthLevel.green);
      expect(h.reasons, isEmpty);
    });

    test('attendance weighs 40, the servants\' work 20 each', () {
      final h = health(
        present: 50,
        taken: 5,
        prepSubmitted: 10,
        absent: 2,
        followed: 1,
      );
      expect(h.score, 50); // 20 + 10 + 10 + 10
      expect(h.level, HealthLevel.amber);
    });

    test('under 50 is red', () {
      final h = health(
        present: 20,
        taken: 2,
        prepSubmitted: 2,
        absent: 4,
        followed: 0,
      );
      expect(h.score, 14); // 8 + 4 + 2 + 0
      expect(h.level, HealthLevel.red);
    });

    test('a part with nothing to measure is left out and the rest re-weighed',
        () {
      // No prep expected: 32 + 20 + 20 out of 80.
      expect(health(prepExpected: 0, prepSubmitted: 0).score, 90);
    });

    test('nothing measurable yet: no score, not flagged', () {
      final h = health(held: 0, taken: 0, present: null, prepExpected: 0);
      expect(h.score, isNull);
      expect(h.level, HealthLevel.green);
    });

    test('no servant is red whatever the numbers', () {
      expect(health(servants: 0).level, HealthLevel.red);
    });

    test('the reports\' attendance % is used when joined in', () {
      final h = ClassHealth.joinAttendance([health(present: 80)], {
        '5 ولاد': 30,
      }).single;
      expect(h.childrenAttendance, 30);
      expect(h.score, 72); // 12 + 20 + 20 + 20
      expect(h.level, HealthLevel.amber);
    });
  });

  group('reasons', () {
    test('attendance recorded on few Saturdays', () {
      final r = health(taken: 7).reasons.first;
      expect(r.text, 'الحضور اتسجّل في 7 من 10 سبوت');
      expect(r.area, HealthArea.attendance);
      expect(r.level, HealthLevel.red);
    });

    test('preps sent', () {
      expect(health(prepSubmitted: 7).reasons.single.text, 'التحضير اترفع 35%');
      expect(health(prepSubmitted: 14).reasons, isEmpty);
    });

    test('absent children without a visit', () {
      expect(health(absent: 2, followed: 2).reasons, isEmpty);
      expect(health(absent: 2, followed: 1).reasons.single.text,
          'طفل غايب من غير افتقاد');
    });

    test('recorded late often', () {
      expect(health(late: 3).reasons, isEmpty);
      expect(health(late: 4).reasons.single.area, HealthArea.late);
    });

    test('worst first', () {
      final h = health(late: 5, prepSubmitted: 2);
      expect(h.reasons.first.level, HealthLevel.red);
      expect(h.reasons.last.level, HealthLevel.amber);
    });
  });

  test('classes sort lowest score first, a class with no servant on top', () {
    final list = [
      health(name: 'ب'),
      health(name: 'أ', present: 20),
      health(name: 'ج', servants: 0),
    ]..sort(ClassHealth.byConcern);
    expect(list.map((c) => c.className), ['ج', 'أ', 'ب']);
  });

  test('parses the database row', () {
    final h = ClassHealth.fromMap(const {
      'class_id': 'x',
      'class_name': '3 بنات',
      'servants_count': 1,
      'active_children': 12,
      'held': 5,
      'taken': 4,
      'taken_late': 1,
      'present_pct': '62.5',
      'prep_expected': 5,
      'prep_submitted': 3,
      'prep_accepted': 2,
      'absent_2plus': 2,
      'absent_followed': 1,
    });
    expect(h.presentPct, 62.5);
    expect(h.prepPct, 60);
    expect(h.absentNotFollowed, 1);
  });
}
