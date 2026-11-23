// The key cards and rows at the largest text sizes the app follows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/app.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/models/class_health.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/data/models/school_class.dart';
import 'package:sabtawya/features/attendance/attendance_screen.dart';
import 'package:sabtawya/features/classes/classes_screen.dart';
import 'package:sabtawya/features/dashboard/home_numbers_card.dart';

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

AttendanceEntry _entry() => AttendanceEntry.from(
      child: const Child(
          id: 'k',
          classId: 'c',
          fullName: 'إيريني رأفت عادل تجريبي',
          gender: Gender.girl,
          isActive: true),
      year: _year,
      record: const AttendanceRecord(
          sessionId: 's',
          childId: 'k',
          sundaySchool: true,
          vespers: false,
          mass: false,
          confession: false,
          score: 5,
          maxScore: 20),
    );

final widgets = <String, Widget Function()>{
  'entryCard': () =>
      AttendanceEntryCard(entry: _entry(), enabled: true, onToggle: (_) {}),
  'entryRow': () =>
      AttendanceEntryRow(entry: _entry(), enabled: true, onToggle: (_) {}),
  'progress': () => const AttendanceProgressLine(
      present: 8, recorded: 80, total: 80, trailing: Icon(Icons.more_vert)),
  'classCard': () => ClassCard(
      overview: const ClassOverview(
          classId: 'c',
          className: '6 بنات',
          sortOrder: 1,
          isActive: true,
          activeChildren: 10,
          boysCount: 4,
          girlsCount: 6,
          servantsCount: 2,
          patronName: 'القديسة إيريني'),
      accent: Colors.blue,
      saturday: DateTime(2026, 11, 21),
      facts: const ClassCardFacts(
          week:
              ClassWeek(classId: 'c', present: 8, children: 10, recorded: true),
          score: 38,
          level: HealthLevel.amber,
          prepSent: false),
      onRecord: () {},
      onTap: () {}),
  'numbers': () => const HomeNumbersCard(
      children: 80, classes: 8, servants: 12, admins: 2, boys: 40, girls: 40),
};

void main() {
  for (final scale in [1.3, kMaxTextScale]) {
    for (final MapEntry(key: name, value: build) in widgets.entries) {
      testWidgets('$name fits at text size $scale', (tester) async {
        tester.view.physicalSize = const Size(375, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(375, 2000),
              textScaler: TextScaler.linear(scale),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: build(),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the app follows the phone text size up to the cap',
      (tester) async {
    for (final (phone, seen) in [
      (1.0, 1.0),
      (1.3, 1.3),
      (2.0, kMaxTextScale)
    ]) {
      tester.platformDispatcher.textScaleFactorTestValue = phone;
      late double got;
      await tester.pumpWidget(MaterialApp(
        builder: appFrame,
        home: Builder(builder: (context) {
          got = MediaQuery.textScalerOf(context).scale(10) / 10;
          return const SizedBox.shrink();
        }),
      ));
      expect(got, closeTo(seen, 0.001), reason: 'phone at $phone');
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
