import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/school_class.dart';
import 'package:sabtawya/features/dashboard/servant_dashboard_screen.dart';

ClassOverview _c(String id,
        {int boys = 0, int girls = 0, int servants = 0}) =>
    ClassOverview(
      classId: id,
      className: 'فصل $id',
      sortOrder: 0,
      isActive: true,
      activeChildren: boys + girls,
      boysCount: boys,
      girlsCount: girls,
      servantsCount: servants,
    );

void main() {
  test('one class: the children with their split, and which class it is', () {
    final t = servantHomeTotals([_c('a', boys: 5, girls: 6, servants: 2)]);
    expect(t.map((x) => x.label), [
      AppStrings.totalChildren,
      AppStrings.yourClass,
    ]);
    expect(t.first.value, 11);
    expect(t.first.sub, '5 ${AppStrings.boys} • 6 ${AppStrings.girls}');
    expect(t.last.text, 'فصل a');
    expect(t.last.value, isNull);
  });

  test('several classes (a general servant): the class count joins in', () {
    final t = servantHomeTotals([
      _c('a', boys: 5, servants: 1),
      _c('b', girls: 4, servants: 2),
    ]);
    expect(t.map((x) => x.label), [
      AppStrings.totalChildren,
      AppStrings.totalClasses,
      AppStrings.totalServants,
    ]);
    expect(t[0].value, 9);
    expect(t[1].value, 2);
    expect(t[2].value, 3);
  });

  test('nothing to say is left out', () {
    final t = servantHomeTotals([_c('a', boys: 3), _c('b')]);
    expect(t.length, 2); // no servants: no servants cell
    expect(t.first.sub, '3 ${AppStrings.boys}');
    expect(servantHomeTotals([_c('a')]).first.sub, isNull);
  });
}
