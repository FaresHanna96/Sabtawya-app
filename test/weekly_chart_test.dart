import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/data/models/reports.dart';
import 'package:sabtawya/features/dashboard/weekly_attendance_chart.dart';

/// A Saturday from its classes, the way the repository builds it.
WeeklyAttendance _week(
  DateTime date,
  List<ClassWeek> classes, {
  bool isBreak = false,
  bool isToday = false,
}) =>
    WeeklyAttendance(
      date: date,
      present:
          classes.where((c) => c.recorded).fold(0, (s, c) => s + c.present),
      children:
          classes.where((c) => c.recorded).fold(0, (s, c) => s + c.children),
      missingClassIds: [
        for (final c in classes)
          if (!c.recorded) c.classId,
      ],
      perClass: classes,
      isBreak: isBreak,
      isToday: isToday,
    );

ClassWeek _c(String id, int present, int children) => ClassWeek(
    classId: id, present: present, children: children, recorded: true);

ClassWeek _none(String id, int children) =>
    ClassWeek(classId: id, present: 0, children: children, recorded: false);

const _names = {'b3': '3 ولاد', 'g3': '3 بنات', 'g6': '6 بنات'};

Future<void> _pump(
  WidgetTester tester,
  List<WeeklyAttendance> weeks, {
  Map<DateTime, double> benchmark = const {},
  void Function(String, DateTime)? onRecord,
}) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: WeeklyAttendanceChart(
            weeks: weeks,
            classNames: _names,
            benchmark: benchmark,
            onRecord: onRecord,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final oct31 = DateTime(2026, 10, 31);
  final nov7 = DateTime(2026, 11, 7);
  final nov14 = DateTime(2026, 11, 14);
  final nov21 = DateTime(2026, 11, 21);

  group('which Saturday the card is about', () {
    final weeks = [
      _week(oct31, [_c('b3', 4, 10), _c('g3', 5, 10)]), // 45%
      _week(nov7, [_c('b3', 6, 10), _c('g3', 4, 10)]), // 50%
      _week(nov14, [_none('b3', 10), _none('g3', 10)]), // nobody
      _week(nov21, [_c('b3', 7, 10), _none('g3', 10)], isToday: true),
    ];

    test('the headline is the latest finished one, not today in progress', () {
      expect(WeeklyAttendance.headline(weeks)!.date, nov7);
    });

    test('today counts once every class has recorded', () {
      final done = [
        ...weeks.take(3),
        _week(nov21, [_c('b3', 7, 10), _c('g3', 6, 10)], isToday: true),
      ];
      expect(WeeklyAttendance.headline(done)!.date, nov21);
    });

    test('the comparison skips gaps and holidays, in points', () {
      final withBreak = [
        weeks[0],
        _week(nov7, [_none('b3', 10), _none('g3', 10)], isBreak: true),
        _week(nov14, [_c('b3', 6, 10), _c('g3', 5, 10)]), // 55%
      ];
      final head = WeeklyAttendance.headline(withBreak)!;
      final prev = WeeklyAttendance.previous(withBreak, head)!;
      expect(prev.date, oct31);
      expect(WeeklyAttendance.pointsChange(head, prev), 10);
    });

    test('a missed Saturday is listed; a holiday and today are not', () {
      final missed = WeeklyAttendance.missedAfter(weeks, weeks[1]);
      expect([for (final w in missed) w.date], [nov14]);
      final asBreak = [
        ...weeks.take(2),
        _week(nov14, [_none('b3', 10)], isBreak: true),
      ];
      expect(WeeklyAttendance.missedAfter(asBreak, asBreak[1]), isEmpty);
    });
  });

  testWidgets('10 Saturdays fit a phone; the headline names its Saturday',
      (tester) async {
    final weeks = [
      for (var i = 0; i < 10; i++)
        WeeklyAttendance(
          date: DateTime(2026, 9, 5 + 7 * i),
          present: 40 + i * 3,
          children: 148,
        ),
    ];
    await _pump(tester, weeks);
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.attendedOn('7/11')), findsOneWidget);
    expect(find.text('67 من 148 مخدوم'), findsOneWidget);
    // 43% to 45%: two points, with both numbers.
    expect(
      find.text('أعلى نقطتين من السبت اللي قبله (من 43% لـ 45%)'),
      findsOneWidget,
    );
    await tester.tap(find.text('5/9'));
    await tester.pumpAndSettle();
    expect(find.text('سبت 5/9: حضر 40 من 148 (27%)'), findsOneWidget);
  });

  testWidgets('a Saturday nobody recorded shows, and a holiday says so',
      (tester) async {
    await _pump(tester, [
      _week(oct31, [_c('b3', 5, 10)]),
      _week(nov7, [_none('b3', 10)], isBreak: true),
      _week(nov14, [_c('b3', 6, 10)]),
      _week(nov21, [_none('b3', 10)]),
    ]);
    expect(find.text('—'), findsOneWidget); // 21/11's bar
    expect(find.text(AppStrings.breakShort), findsOneWidget); // 7/11's bar
    expect(find.text(AppStrings.saturdaysMissed(['21/11'])), findsOneWidget);
    // The headline stays on the last recorded Saturday.
    expect(find.text(AppStrings.attendedOn('14/11')), findsOneWidget);
    await tester.tap(find.text('7/11'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.weekBreak('7/11')), findsOneWidget);
  });

  testWidgets('a class that did not record: named once, its chip opens it',
      (tester) async {
    final opened = <(String, DateTime)>[];
    await _pump(
      tester,
      [
        _week(oct31, [_c('b3', 5, 10), _c('g3', 5, 10), _c('g6', 5, 10)]),
        _week(nov7, [_c('b3', 6, 10), _none('g3', 10), _none('g6', 10)]),
      ],
      onRecord: (id, date) => opened.add((id, date)),
    );
    expect(find.text(AppStrings.notRecordedLabel), findsOneWidget);
    await tester.tap(find.text('6 بنات'));
    expect(opened, [('g6', nov7)]);
  });

  testWidgets('each class that Saturday, lowest first', (tester) async {
    await _pump(tester, [
      _week(oct31, [_c('b3', 5, 10)]),
      _week(nov7, [_c('b3', 8, 10), _c('g3', 3, 10), _c('g6', 6, 10)]),
    ]);
    // Every class recorded: no "did not record" chips, one line each.
    expect(find.text(AppStrings.notRecordedLabel), findsNothing);
    final names = ['3 بنات', '6 بنات', '3 ولاد'];
    final tops = [for (final n in names) tester.getTopLeft(find.text(n)).dy];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('the service-wide % shows only when given', (tester) async {
    final weeks = [
      _week(oct31, [_c('b3', 5, 10)]),
      _week(nov7, [_c('b3', 6, 10)]),
    ];
    await _pump(tester, weeks);
    expect(find.textContaining('الخدمة كلها'), findsNothing);
    await _pump(tester, weeks, benchmark: {nov7: 51.4});
    // In the headline and in the detail box (both on 7/11).
    expect(find.text(AppStrings.serviceWide(51)), findsNWidgets(2));
  });

  testWidgets('today still being recorded is labelled and not a warning',
      (tester) async {
    await _pump(tester, [
      _week(nov14, [_c('b3', 6, 10), _c('g3', 6, 10)]),
      _week(nov21, [_c('b3', 7, 10), _none('g3', 10)], isToday: true),
    ]);
    expect(find.text(AppStrings.todayBar), findsOneWidget);
    // The box below starts on today and lists who is still recording.
    expect(find.text(AppStrings.stillRecording), findsOneWidget);
    expect(find.text(AppStrings.notRecordedLabel), findsNothing);
    expect(find.text(AppStrings.attendedOn('14/11')), findsOneWidget);
    // Said once: the headline's "today" note only while another bar is open.
    expect(find.text(AppStrings.todayProgress(1, 2)), findsNothing);
    await tester.tap(find.text('14/11'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.todayProgress(1, 2)), findsOneWidget);
  });

  test('level colours: green 60+, amber 40+, red below', () {
    expect(WeeklyAttendanceChart.levelColor(60), AppColors.success);
    expect(WeeklyAttendanceChart.levelColor(45), AppColors.warning);
    expect(WeeklyAttendanceChart.levelColor(39), AppColors.danger);
  });
}
