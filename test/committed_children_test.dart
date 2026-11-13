import 'package:flutter_test/flutter_test.dart';
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

  test('3 and 4 keep only that exact run', () {
    expect(CommittedChildrenScreen.filter(all, min: 3).map((r) => r.childName),
        ['أ']);
    expect(CommittedChildrenScreen.filter(all, min: 4).map((r) => r.childName),
        ['ج']);
  });

  test('5+ keeps only runs of five or more', () {
    final rows = CommittedChildrenScreen.filter(all, min: 5);
    expect(rows.map((r) => r.childName), ['ب']);
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
