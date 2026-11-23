import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/features/children/absence_followup_screen.dart';
import 'package:sabtawya/features/children/committed_children_screen.dart';

ChildStreak _s(String name, String cls, int present) => ChildStreak(
      childId: name,
      childName: name,
      classId: cls,
      className: cls,
      absentStreak: 0,
      presentStreak: present,
    );

void main() {
  final all = [
    _s('أ', 'c1', 3),
    _s('ب', 'c1', 6),
    _s('ج', 'c2', 4),
    _s('د', 'c2', 2),
  ];

  test('tiers: 3 alone, 4 to 15 (ملتزم), 16 and more (ذهبي)', () {
    final runs = [
      ...all,
      _s('هـ', 'c1', 15),
      _s('و', 'c2', 16),
      _s('ز', 'c1', 20),
    ];
    Iterable<String> names(int min) =>
        CommittedChildrenScreen.filter(runs, min: min).map((r) => r.childName);
    expect(names(3), ['أ']);
    expect(names(4), ['هـ', 'ب', 'ج']);
    expect(names(16), ['ز', 'و']);
  });

  test('what each run is still short of', () {
    expect(CommittedChildrenScreen.nextGoal(3), AppStrings.oneLeftForCommitted);
    expect(CommittedChildrenScreen.nextGoal(4), AppStrings.leftForGold(12));
    expect(CommittedChildrenScreen.nextGoal(15), AppStrings.leftForGold(1));
    expect(CommittedChildrenScreen.nextGoal(16), isNull);
  });

  test('class filter limits to the chosen classes', () {
    final rows = CommittedChildrenScreen.filter(all, min: 4, classIds: {'c2'});
    expect(rows.map((r) => r.childName), ['ج']);
  });

  test('absence chips: 2 and 3 exact, 4 means four or more', () {
    expect(AbsenceFollowUpScreen.inChip(2, 2), isTrue);
    expect(AbsenceFollowUpScreen.inChip(3, 2), isFalse);
    expect(AbsenceFollowUpScreen.inChip(3, 3), isTrue);
    expect(AbsenceFollowUpScreen.inChip(4, 3), isFalse);
    expect(AbsenceFollowUpScreen.inChip(4, 4), isTrue);
    expect(AbsenceFollowUpScreen.inChip(9, 4), isTrue);
  });
}
