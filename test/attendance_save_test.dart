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

/// A sheet line as it was opened: [recorded] children have a saved row.
AttendanceEntry _line(
  String name, {
  bool recorded = false,
  bool vespers = false,
}) =>
    AttendanceEntry.from(
      child: Child(
        id: name,
        classId: 'class-1',
        fullName: name,
        gender: Gender.boy,
        isActive: true,
      ),
      record: recorded
          ? AttendanceRecord(
              sessionId: 's1',
              childId: name,
              sundaySchool: false,
              vespers: vespers,
              mass: false,
              confession: false,
              score: vespers ? 5 : 0,
              maxScore: 20,
            )
          : null,
      year: _year,
    );

AttendanceSavePlan _plan(
  List<AttendanceEntry> originals,
  void Function(List<AttendanceEntry> entries) edit,
) {
  final entries = [for (final o in originals) o.clone()];
  edit(entries);
  return AttendanceSavePlan.build(
    sessionId: 's1',
    entries: entries,
    originals: originals,
  );
}

void main() {
  test('a changed child sends only the marks that changed', () {
    final plan = _plan(
      [_line('a', recorded: true, vespers: true)],
      (e) => e[0].mass = true,
    );

    // vespers (maybe set by a co-servant) is not in the payload, so the
    // database leaves it as it is.
    expect(plan.updates, [
      [
        {'session_id': 's1', 'child_id': 'a', 'mass': true},
      ],
    ]);
    expect(plan.insertIfMissing, isEmpty);
  });

  test('an untouched child with a saved row sends nothing', () {
    final plan = _plan([_line('a', recorded: true)], (_) {});

    expect(plan.isEmpty, isTrue);
  });

  test(
      'an untouched child with no row is stored as absent only if still '
      'missing, never over a co-servant\'s row', () {
    final plan = _plan(
      [_line('a'), _line('b')],
      (e) => e[0].sundaySchool = true,
    );

    expect(plan.updates.single.single,
        {'session_id': 's1', 'child_id': 'a', 'sunday_school': true});
    // No marks at all: an insert that the database skips when a row exists.
    expect(plan.insertIfMissing, [
      {'session_id': 's1', 'child_id': 'b'},
    ]);
  });

  test('children with the same changed marks travel in one request', () {
    final plan = _plan(
      [_line('a'), _line('b'), _line('c', recorded: true, vespers: true)],
      (e) {
        e[0].mass = true;
        e[1].mass = true;
        e[2]
          ..mass = true
          ..vespers = false;
      },
    );

    expect(plan.updates, hasLength(2));
    for (final group in plan.updates) {
      // One request needs the same columns in every row.
      expect({for (final row in group) row.keys.join(',')}, hasLength(1));
    }
    expect(plan.updates.expand((g) => g).map((r) => r['child_id']),
        unorderedEquals(['a', 'b', 'c']));
  });

  test('a mark turned off is sent as false', () {
    final plan = _plan(
      [_line('a', recorded: true, vespers: true)],
      (e) => e[0].vespers = false,
    );

    expect(plan.updates.single.single,
        {'session_id': 's1', 'child_id': 'a', 'vespers': false});
  });
}
