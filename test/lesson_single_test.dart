import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/lesson.dart';
import 'package:sabtawya/features/lessons/lesson_widgets.dart';

void main() {
  testWidgets('a lone lesson: the tag, its page, the title, a labelled button',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SizedBox(
            width: 330,
            child: LessonSingle(
              grade: 3,
              lesson: Lesson(
                slot: LessonSlot(1, 3),
                grade: 3,
                title: 'الاحترام: قورح وداثان وأبيرام',
                page: 104,
              ),
            ),
          ),
        ),
      ),
    ));
    expect(find.text(AppStrings.gradeLabel(3)), findsOneWidget);
    expect(find.text('${AppStrings.page} 104'), findsOneWidget);
    expect(find.text('الاحترام: قورح وداثان وأبيرام'), findsOneWidget);
    expect(find.text(AppStrings.materialsLink), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
