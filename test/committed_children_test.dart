import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/reports.dart';
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

  test('keeps runs at least the threshold, longest first', () {
    final rows = CommittedChildrenScreen.filter(all, min: 3);
    expect(rows.map((r) => r.childName), ['ب', 'ج', 'أ']);
  });

  test('5+ keeps only runs of five or more', () {
    final rows = CommittedChildrenScreen.filter(all, min: 5);
    expect(rows.map((r) => r.childName), ['ب']);
  });

  test('class filter limits to the chosen classes', () {
    final rows =
        CommittedChildrenScreen.filter(all, min: 3, classIds: {'c2'});
    expect(rows.map((r) => r.childName), ['ج']);
  });
}
