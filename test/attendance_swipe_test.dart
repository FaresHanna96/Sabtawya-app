import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/attendance/attendance_screen.dart';
import 'package:sabtawya/features/attendance/attendance_swipe.dart';

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

AttendanceEntry _entry(String marks) => AttendanceEntry.from(
      child: const Child(
        id: 'k',
        classId: 'c',
        fullName: 'مخدوم',
        gender: Gender.girl,
        isActive: true,
      ),
      year: _year,
      record: AttendanceRecord(
        sessionId: 's',
        childId: 'k',
        sundaySchool: marks[0] == '1',
        vespers: marks[1] == '1',
        mass: marks[2] == '1',
        confession: marks[3] == '1',
        score: 0,
        maxScore: 20,
      ),
    );

class _Calls {
  int all = 0;
  int clear = 0;
  int long = 0;
}

Future<_Calls> _pump(WidgetTester tester, {bool enabled = true}) async {
  final calls = _Calls();
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: AttendanceSwipe(
              id: 'k',
              enabled: enabled,
              onAllPresent: () => calls.all++,
              onClear: () => calls.clear++,
              onLongPress: () => calls.long++,
              child: Container(
                key: const Key('line'),
                height: 72,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  return calls;
}

void main() {
  group('setEntryMarks', () {
    test('present at everything', () {
      final e = _entry('1000');
      setEntryMarks(e, present: true);
      expect([e.sundaySchool, e.vespers, e.mass, e.confession],
          [true, true, true, true]);
    });

    test('every mark cleared', () {
      final e = _entry('1011');
      setEntryMarks(e, present: false);
      expect(e.isPresent, isFalse);
    });
  });

  group('AttendanceSwipe (Arabic, right to left)', () {
    testWidgets('a swipe towards the left marks present at everything',
        (tester) async {
      final calls = await _pump(tester);
      await tester.drag(find.byKey(const Key('line')), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(calls.all, 1);
      expect(calls.clear, 0);
      // The line springs back: still on screen.
      expect(find.byKey(const Key('line')), findsOneWidget);
    });

    testWidgets('a swipe towards the right clears the marks', (tester) async {
      final calls = await _pump(tester);
      await tester.drag(find.byKey(const Key('line')), const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(calls.clear, 1);
      expect(calls.all, 0);
    });

    testWidgets('a short slip does nothing', (tester) async {
      final calls = await _pump(tester);
      await tester.drag(find.byKey(const Key('line')), const Offset(-40, 0));
      await tester.pumpAndSettle();
      expect(calls.all + calls.clear, 0);
    });

    testWidgets('the swipe says what it does', (tester) async {
      await _pump(tester);
      final gesture = await tester
          .startGesture(tester.getCenter(find.byKey(const Key('line'))));
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-130, 0));
      await tester.pump();
      expect(find.text(AppStrings.swipeAllPresent), findsOneWidget);
      expect(find.text(AppStrings.swipeClear), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the other way says it clears', (tester) async {
      await _pump(tester);
      final gesture = await tester
          .startGesture(tester.getCenter(find.byKey(const Key('line'))));
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(130, 0));
      await tester.pump();
      expect(find.text(AppStrings.swipeClear), findsOneWidget);
      expect(find.text(AppStrings.swipeAllPresent), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('locked: no swipe, the long press still opens the child',
        (tester) async {
      final calls = await _pump(tester, enabled: false);
      await tester.drag(find.byKey(const Key('line')), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(calls.all + calls.clear, 0);
      await tester.longPress(find.byKey(const Key('line')));
      expect(calls.long, 1);
    });

    testWidgets('a long press opens the child', (tester) async {
      final calls = await _pump(tester);
      await tester.longPress(find.byKey(const Key('line')));
      expect(calls.long, 1);
    });
  });

  group('on a real attendance line', () {
    Future<List<AttendanceActivity>> pumpLine(WidgetTester tester,
        {bool compact = false, VoidCallback? onAll}) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tapped = <AttendanceActivity>[];
      final entry = _entry('0000');
      final line = compact
          ? AttendanceEntryRow(
              entry: entry, enabled: true, onToggle: tapped.add)
          : AttendanceEntryCard(
              entry: entry, enabled: true, onToggle: tapped.add);
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ListView(children: [
              AttendanceSwipe(
                id: 'k',
                enabled: true,
                onAllPresent: onAll ?? () {},
                onClear: () {},
                child: line,
              ),
            ]),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return tapped;
    }

    testWidgets('the card shows, and its marks still respond to a tap',
        (tester) async {
      final tapped = await pumpLine(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('مخدوم'), findsOneWidget);
      await tester.tap(find.text(AppStrings.massShort));
      expect(tapped, [AttendanceActivity.mass]);
    });

    testWidgets('the compact line shows and swipes', (tester) async {
      var all = 0;
      await pumpLine(tester, compact: true, onAll: () => all++);
      expect(tester.takeException(), isNull);
      expect(find.text('مخدوم'), findsOneWidget);
      await tester.drag(find.text('مخدوم'), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(all, 1);
    });
  });
}
