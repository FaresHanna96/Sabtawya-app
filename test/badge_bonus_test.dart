import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/badges.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/data/repositories/badge_repository.dart';

ChildBadge _b(String child, DateTime? on) => ChildBadge(
      childId: child,
      classId: 'c',
      badge: KidBadge.streak4,
      earnedOn: on,
      progress: 0,
      target: 4,
    );

ChildYearReport _year(String id, int points) => ChildYearReport(
      childId: id,
      childName: 'n',
      gender: Gender.girl,
      classId: 'c',
      className: 'c',
      yearId: 'y',
      sessionsTotal: 10,
      sessionsAttended: 8,
      points: points,
      maxPoints: 200,
      percentage: 80,
      childIsActive: true,
    );

ChildMonthlyReport _month(String id, DateTime start, int points) =>
    ChildMonthlyReport(
      childId: id,
      childName: 'n',
      gender: Gender.girl,
      classId: 'c',
      className: 'c',
      yearId: 'y',
      monthStart: start,
      sessionsTotal: 4,
      sessionsAttended: 3,
      points: points,
      maxPoints: 80,
      percentage: 75,
      childIsActive: true,
    );

void main() {
  final bonus = BadgeBonus.of([
    _b('a', DateTime(2026, 10, 3)),
    _b('a', DateTime(2026, 11, 7)),
    _b('a', DateTime(2026, 11, 28)),
    _b('a', null), // not earned: adds nothing
    _b('b', DateTime(2026, 11, 14)),
  ]);

  test('+10 for every badge earned, none for the ones still to earn', () {
    expect(bonus.year('a'), 30);
    expect(bonus.year('b'), 10);
    expect(bonus.year('nobody'), 0);
  });

  test('a month counts the badges earned in it, its last day included', () {
    expect(bonus.inMonth('a', DateTime(2026, 11)), 20);
    expect(bonus.inMonth('a', DateTime(2026, 10)), 10);
    expect(bonus.inMonth('a', DateTime(2026, 9)), 0);
  });

  test('a period counts the badges earned inside it, both ends included', () {
    expect(bonus.between('a', from: DateTime(2026, 11, 7)), 20);
    expect(
      bonus.between('a', from: DateTime(2026, 10, 4), to: DateTime(2026, 11, 7)),
      10,
    );
    expect(bonus.between('a', to: DateTime(2026, 10, 3)), 10);
  });

  test('reports show attendance points plus the bonus, % untouched', () {
    final y = bonus.forYear(_year('a', 85));
    expect(y.points, 85);
    expect(y.bonus, 30);
    expect(y.total, 115);
    expect(y.percentage, 80);

    final m = bonus.forMonth(_month('a', DateTime(2026, 11), 40));
    expect(m.total, 60);
    expect(bonus.forMonth(_month('a', DateTime(2026, 9), 40)).total, 40);
  });

  test('without the badges nothing changes', () {
    expect(BadgeBonus.none.forYear(_year('a', 85)).total, 85);
  });
}
