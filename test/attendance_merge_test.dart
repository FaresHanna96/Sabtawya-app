import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';

final _year = AttendanceYear(
  id: 'year-1',
  name: '2026 - 2027',
  startDate: DateTime(2026, 10, 24),
  endDate: DateTime(2027, 9, 25),
  sessionWeekday: 6,
  pointsSundaySchool: 5,
  pointsVespers: 5,
  pointsMass: 5,
  pointsConfession: 5,
  maxPointsPerSession: 20,
  isCurrent: true,
);

AttendanceEntry _entry({AttendanceRecord? record}) => AttendanceEntry.from(
      child: Child(
        id: 'k1',
        classId: 'c1',
        fullName: 'مينا',
        gender: Gender.boy,
        isActive: true,
      ),
      record: record,
      year: _year,
    );

AttendanceRecord _record({bool sundaySchool = false, bool vespers = false}) =>
    AttendanceRecord(
      sessionId: 's1',
      childId: 'k1',
      sundaySchool: sundaySchool,
      vespers: vespers,
      mass: false,
      confession: false,
      score: 0,
      maxScore: 20,
    );

/// What the screen does when a co-servant's save arrives: [local] is the line
/// on screen, [original] what the server held when the sheet was opened.
bool _arrives(
  AttendanceEntry local,
  AttendanceEntry original, {
  bool sundaySchool = false,
  bool vespers = false,
  bool mass = false,
  bool confession = false,
}) =>
    local.mergeRemote(
      original,
      sundaySchool: sundaySchool,
      vespers: vespers,
      mass: mass,
      confession: confession,
      updatedAt: DateTime(2026, 11, 16, 11),
      updatedByName: 'مريم',
    );

void main() {
  test('a line nobody touched here takes the saved marks', () {
    final local = _entry();
    final original = local.clone();

    final changed = _arrives(local, original, vespers: true, mass: true);

    expect(changed, isTrue);
    expect(
        [local.sundaySchool, local.vespers, local.mass], [false, true, true]);
    expect(local.isRecorded, isTrue);
    expect(local.updatedByName, 'مريم');
    // What the server holds now, so nothing here counts as a change.
    expect(local.sameMarksAs(original), isTrue);
    expect(local.changedFlags(original), isEmpty);
  });

  test('a mark touched here is kept, the others take the saved value', () {
    final local = _entry();
    final original = local.clone();
    local.sundaySchool = true; // this servant marked it, not saved yet

    _arrives(local, original, vespers: true);

    expect(local.sundaySchool, isTrue); // still theirs
    expect(local.vespers, isTrue); // arrived
    // Saving now sends only the mark they made.
    expect(local.changedFlags(original), {'sunday_school': true});
  });

  test('both changed the same mark: the screen keeps this servant\'s value',
      () {
    final local = _entry();
    final original = local.clone();
    local.mass = true;

    _arrives(local, original, mass: false);

    expect(local.mass, isTrue);
    expect(original.mass, isFalse); // the server's value
    expect(local.changedFlags(original), {'mass': true});
  });

  test('both arrived at the same value: nothing left to save', () {
    final local = _entry();
    final original = local.clone();
    local.vespers = true;

    _arrives(local, original, vespers: true);

    expect(local.changedFlags(original), isEmpty);
  });

  test('a mark turned off elsewhere is turned off here', () {
    final local = _entry(record: _record(sundaySchool: true, vespers: true));
    final original = local.clone();

    final changed = _arrives(local, original, sundaySchool: true);

    expect(changed, isTrue);
    expect(local.vespers, isFalse);
    expect(local.sundaySchool, isTrue);
  });

  test('the same marks arriving again change nothing to look at', () {
    final local = _entry(record: _record(vespers: true));
    final original = local.clone();

    expect(_arrives(local, original, vespers: true), isFalse);
  });

  test('a child nobody had recorded becomes recorded', () {
    final local = _entry();
    final original = local.clone();
    expect(local.isRecorded, isFalse);

    // An absent line arrives (all marks off): still news, the line was empty.
    expect(_arrives(local, original), isTrue);
    expect(local.isRecorded, isTrue);
    expect(original.isRecorded, isTrue);
  });
}
