import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/lesson.dart';
import 'package:sabtawya/features/lessons/lesson_widgets.dart';

Lesson _l(int grade, String title, int? page) => Lesson(
      slot: const LessonSlot(1, 3),
      grade: grade,
      title: title,
      page: page,
    );

Future<void> _pump(WidgetTester t, Widget w, {double width = 330}) =>
    t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: SizedBox(width: width, child: w)),
        ),
      ),
    ));

void main() {
  testWidgets('a short lesson is one compact line', (t) async {
    await _pump(
      t,
      LessonRow(
        grade: 4,
        lesson: _l(4, 'أنا ناجح: يوسف الصديق', 95),
        last: true,
      ),
    );
    final tag = t.getRect(find.text(AppStrings.gradeLabel(4)));
    final title = t.getRect(find.textContaining('يوسف'));
    final page = t.getRect(find.text('${AppStrings.page} 95'));
    final clip = t.getRect(find.byIcon(Icons.attach_file_rounded));
    for (final r in [title, page, clip]) {
      expect((tag.center.dy - r.center.dy).abs(), lessThan(4));
    }
    // The whole row is about 40 high, not two stacked lines.
    expect(t.getSize(find.byType(LessonRow)).height, lessThan(50));
    expect(t.takeException(), isNull);
  });

  testWidgets('the page is never broken into «ص» and «94»', (t) async {
    await _pump(
      t,
      LessonRow(
        grade: 3,
        lesson: _l(3, 'الاحترام: قورح وداثان وأبيرام، إحترام البابا ديمتريوس '
            'لمعلمه', 104),
        last: false,
      ),
      width: 260,
    );
    final page = t.getRect(find.text('${AppStrings.page} 104'));
    expect(page.height, lessThan(20)); // one line high
  });

  testWidgets('no page: just the tag and the title', (t) async {
    await _pump(
      t,
      LessonRow(grade: 4, lesson: _l(4, 'أنا ناجح', null), last: true),
    );
    expect(find.text(AppStrings.gradeLabel(4)), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) =>
          w is Text && RegExp('^${AppStrings.page} [0-9]').hasMatch(w.data ?? '')),
      findsNothing,
    );
    expect(find.text('أنا ناجح'), findsOneWidget);
  });
}
