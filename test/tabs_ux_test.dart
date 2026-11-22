import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/attendance/attendance_draft.dart';
import 'package:sabtawya/features/attendance/attendance_screen.dart';
import 'package:sabtawya/features/children/child_tile.dart';
import 'package:sabtawya/features/children/contact_cards.dart';
import 'package:sabtawya/features/classes/classes_screen.dart';

final _year = AttendanceYear(
  id: 'year-1',
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

Child _child(String id, {String? mobile, String? mother, bool active = true}) =>
    Child(
      id: id,
      classId: 'c',
      fullName: 'مخدوم $id',
      gender: Gender.boy,
      isActive: active,
      mobile: mobile,
      motherMobile: mother,
    );

AttendanceEntry _entry(String id, [String marks = '0000']) =>
    AttendanceEntry.from(
      child: _child(id),
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

Widget _rtl(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('unsaved attendance marks (draft)', () {
    test('only the children whose marks changed are kept', () {
      final originals = [_entry('a'), _entry('b', '1000')];
      final entries = [_entry('a', '1100'), _entry('b', '1000')];
      expect(AttendanceDraft.changes(entries, originals), {'a': '0000>1100'});
    });

    test('restored where nobody changed the child since', () {
      final originals = [_entry('a'), _entry('b')];
      final entries = [_entry('a'), _entry('b')];
      final n = AttendanceDraft.restore(
        {'a': '0000>1011'},
        entries,
        originals,
      );
      expect(n, 1);
      expect(AttendanceDraft.marksOf(entries[0]), '1011');
      expect(AttendanceDraft.marksOf(entries[1]), '0000');
    });

    test('a co-servant\'s newer marks win over the draft', () {
      // The draft started from 0000, but the saved marks are now 1000.
      final originals = [_entry('a', '1000')];
      final entries = [_entry('a', '1000')];
      final n = AttendanceDraft.restore(
        {'a': '0000>0110'},
        entries,
        originals,
      );
      expect(n, 0);
      expect(AttendanceDraft.marksOf(entries[0]), '1000');
    });

    test('a locked class is not restored', () {
      final entries = [_entry('a')];
      final n = AttendanceDraft.restore(
        {'a': '0000>1111'},
        entries,
        [_entry('a')],
        canEdit: (_) => false,
      );
      expect(n, 0);
    });

    test('kept, read back, cleared, and dropped once stale', () async {
      final d = AttendanceDraft.memory();
      final now = DateTime(2026, 11, 21);
      await d.write('s1', {'a': '0000>1000'}, now: now);
      expect(await d.read('s1', now: now), {'a': '0000>1000'});

      await d.clear('s1');
      expect(await d.read('s1', now: now), isEmpty);

      await d.write('s1', {'a': '0000>1000'}, now: now);
      final later = now.add(AttendanceDraft.keepFor + const Duration(days: 1));
      expect(await d.read('s1', now: later), isEmpty);
    });

    test('nothing changed clears the draft', () async {
      final d = AttendanceDraft.memory();
      await d.write('s1', {'a': '0000>1000'});
      await d.write('s1', const {});
      expect(await d.read('s1'), isEmpty);
    });

    test('the compact choice is remembered', () async {
      final d = AttendanceDraft.memory();
      expect(await d.compact(), isFalse);
      await d.setCompact(true);
      expect(await d.compact(), isTrue);
    });
  });

  group('mark all', () {
    test('one activity leaves the others alone', () {
      final entries = [_entry('a', '0100'), _entry('b')];
      markAllEntries(entries,
          present: true, only: AttendanceActivity.mass, canEdit: (_) => true);
      expect(entries.map(AttendanceDraft.marksOf), ['0110', '0010']);
    });

    test('all four, skipping what cannot be edited', () {
      final entries = [_entry('a'), _entry('b')];
      markAllEntries(entries, present: true, canEdit: (i) => i == 0);
      expect(entries.map(AttendanceDraft.marksOf), ['1111', '0000']);
    });
  });

  testWidgets('a compact row: the name and four round marks', (tester) async {
    final tapped = <AttendanceActivity>[];
    await tester.pumpWidget(_rtl(SizedBox(
      width: 375,
      child: AttendanceEntryRow(
        entry: _entry('a', '1000'),
        enabled: true,
        onToggle: tapped.add,
      ),
    )));
    expect(find.text('مخدوم a'), findsOneWidget);
    await tester.tap(find.byTooltip(AppStrings.massShort));
    expect(tapped, [AttendanceActivity.mass]);
  });

  group('الفصول', () {
    test('a class keeps its colour whatever its position', () {
      final a = classColourIndex('class-42', 6);
      expect(classColourIndex('class-42', 6), a);
      expect(a, inInclusiveRange(0, 5));
    });

    testWidgets('not recorded yet: says so with a button to record',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(_rtl(SizedBox(
        width: 360,
        child: ClassSaturdayStatus(
          recorded: false,
          day: '21 نوفمبر',
          onRecord: () => opened++,
        ),
      )));
      expect(find.text('لم يُسجَّل حضور 21 نوفمبر بعد'), findsOneWidget);
      await tester.tap(find.text(AppStrings.recordNow));
      expect(opened, 1);
    });

    testWidgets('recorded: no button', (tester) async {
      await tester.pumpWidget(_rtl(SizedBox(
        width: 360,
        child: ClassSaturdayStatus(
          recorded: true,
          day: '21 نوفمبر',
          onRecord: () {},
        ),
      )));
      expect(find.text('اتسجّل حضور 21 نوفمبر'), findsOneWidget);
      expect(find.text(AppStrings.recordNow), findsNothing);
    });
  });

  group('المخدومين: calling from the list', () {
    test('only people with a number are listed', () {
      final people = ContactPerson.forChild(
          _child('a', mobile: ' ', mother: '01012345678'));
      expect(people.map((p) => p.label), [AppStrings.callMother]);
    });

    testWidgets('the phone button shows only when there is a number',
        (tester) async {
      var asked = 0;
      await tester.pumpWidget(_rtl(Column(children: [
        ChildTile(
          child: _child('a', mother: '01012345678'),
          onTap: () {},
          onContact: () => asked++,
        ),
        ChildTile(
          child: _child('b'),
          onTap: () {},
          onContact: () => asked++,
        ),
      ])));
      expect(find.byTooltip(AppStrings.call), findsOneWidget);
      await tester.tap(find.byTooltip(AppStrings.call));
      expect(asked, 1);
    });
  });
}
