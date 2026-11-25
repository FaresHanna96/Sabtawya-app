import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/features/children/child_tile.dart';

ChildStreak _s({required int absent, required int present, DateTime? last}) =>
    ChildStreak(
      childId: 'k',
      childName: 'م',
      classId: 'c',
      className: 'ف',
      absentStreak: absent,
      presentStreak: present,
      lastPresentDate: last,
    );

void main() {
  test('nothing while the streaks are loading', () {
    expect(lastSeenText(null), isNull);
  });

  test('came to the last Saturday', () {
    expect(lastSeenText(_s(absent: 0, present: 3, last: DateTime(2026, 11, 21))),
        AppStrings.cameLastSaturday);
  });

  test('missed some: says when they last came', () {
    final t = lastSeenText(_s(absent: 2, present: 0, last: DateTime(2026, 10, 31)));
    expect(t, startsWith(AppStrings.lastPresent));
  });

  test('never came', () {
    expect(lastSeenText(_s(absent: 5, present: 0)), AppStrings.neverCame);
  });
}
