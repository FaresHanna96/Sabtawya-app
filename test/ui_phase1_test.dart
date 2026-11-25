import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/features/attendance/attendance_draft.dart';
import 'package:sabtawya/features/attendance/attendance_screen.dart';
import 'package:sabtawya/features/children/absence_followup_screen.dart';

final _year = AttendanceYear(
  id: 'y',
  name: '2026 - 2027',
  startDate: DateTime(2026, 9, 26),
  endDate: DateTime(2027, 6, 26),
  sessionWeekday: 6,
  pointsSundaySchool: 5,
  pointsVespers: 5,
  pointsMass: 5,
  pointsConfession: 5,
  maxPointsPerSession: 20,
  isCurrent: true,
);

AttendanceEntry _entry(String id, String marks) => AttendanceEntry.from(
      child: Child(
        id: id,
        classId: 'c',
        fullName: 'مخدوم $id',
        gender: Gender.girl,
        isActive: true,
      ),
      year: _year,
      record: AttendanceRecord(
        sessionId: 's',
        childId: id,
        sundaySchool: marks[0] == '1',
        vespers: marks[1] == '1',
        mass: marks[2] == '1',
        confession: marks[3] == '1',
        score: 0,
        maxScore: 20,
      ),
    );

ChildStreak _streak({DateTime? lastPresent}) => ChildStreak(
      childId: 'k',
      childName: 'مخدوم',
      classId: 'c',
      className: 'فصل',
      absentStreak: 2,
      presentStreak: 0,
      lastPresentDate: lastPresent,
    );

void main() {
  group('undo after all-present', () {
    test('snapshot then restore brings the earlier marks back', () {
      final entries = [_entry('a', '1000'), _entry('b', '0101')];
      final before = AttendanceDraft.snapshot(entries);
      expect(before, ['1000', '0101']);

      markAllEntries(entries, present: true, canEdit: (_) => true);
      expect(AttendanceDraft.snapshot(entries), ['1111', '1111']);

      AttendanceDraft.restoreSnapshot(entries, before);
      expect(AttendanceDraft.snapshot(entries), ['1000', '0101']);
    });

    test('a snapshot of another length is ignored', () {
      final entries = [_entry('a', '1000')];
      AttendanceDraft.restoreSnapshot(entries, ['0000', '1111']);
      expect(AttendanceDraft.snapshot(entries), ['1000']);
    });
  });

  group('follow-up', () {
    test('followed up only when visited since the last time they came', () {
      final present = DateTime(2026, 11, 7);
      const base = Child(
        id: 'k',
        classId: 'c',
        fullName: 'مخدوم',
        gender: Gender.girl,
        isActive: true,
      );
      expect(isFollowedUp(_streak(lastPresent: present), base), isFalse);
      final visited = Child(
        id: 'k',
        classId: 'c',
        fullName: 'مخدوم',
        gender: Gender.girl,
        isActive: true,
        lastPhoneVisitDate: DateTime(2026, 11, 10),
      );
      expect(isFollowedUp(_streak(lastPresent: present), visited), isTrue);
      final old = Child(
        id: 'k',
        classId: 'c',
        fullName: 'مخدوم',
        gender: Gender.girl,
        isActive: true,
        lastHomeVisitDate: DateTime(2026, 10, 1),
      );
      expect(isFollowedUp(_streak(lastPresent: present), old), isFalse);
    });

    testWidgets('progress strip shows the count and fills the bar',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: FollowUpProgressStrip(done: 1, total: 4)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.followedUpProgress(1, 4)), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(0.25, 0.001));
    });
  });
}
