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
  test('a class doing well is green with no reasons', () {
    final h = health();
    expect(h.reasons, isEmpty);
    expect(h.level, HealthLevel.green);
  });

  test('no servant is red', () {
    expect(health(servants: 0, prepExpected: 0).level, HealthLevel.red);
  });

  test('attendance recorded: under 90% amber, under 75% red', () {
    expect(health(taken: 9).level, HealthLevel.green);
    expect(health(taken: 8).level, HealthLevel.amber);
    expect(health(taken: 7).level, HealthLevel.red);
    expect(health(taken: 7).reasons.first.text, 'الحضور اتسجّل في 7 من 10 سبوت');
    expect(health(taken: 7).reasons.first.area, HealthArea.attendance);
  });

  test('recorded late more than 30% of the time is amber', () {
    expect(health(late: 3).level, HealthLevel.green);
    expect(health(late: 4).level, HealthLevel.amber);
  });

  test('preps: under 70% amber, under 40% red, none expected is fine', () {
    expect(health(prepSubmitted: 14).level, HealthLevel.green);
    expect(health(prepSubmitted: 13).level, HealthLevel.amber);
    expect(health(prepSubmitted: 7).level, HealthLevel.red);
    expect(health(prepSubmitted: 7).reasons.single.text, 'التحضير اترفع 35%');
    expect(health(prepExpected: 0, prepSubmitted: 0).level, HealthLevel.green);
  });

  test('absent children without a visit: one amber, three red', () {
    expect(health(absent: 2, followed: 2).level, HealthLevel.green);
    expect(health(absent: 2, followed: 1).level, HealthLevel.amber);
    expect(health(absent: 4, followed: 1).level, HealthLevel.red);
  });

  test('low attendance is amber; no marks yet says nothing', () {
    expect(health(present: 45).level, HealthLevel.amber);
    expect(health(present: null).level, HealthLevel.green);
  });

  test('reasons come worst first', () {
    final h = health(late: 5, prepSubmitted: 2);
    expect(h.reasons.first.level, HealthLevel.red);
    expect(h.reasons.last.level, HealthLevel.amber);
  });

  test('classes sort worst first, then by name', () {
    final list = [
      health(name: 'ب'),
      health(name: 'أ', taken: 8),
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
