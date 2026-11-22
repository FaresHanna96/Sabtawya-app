import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/core/theme/class_colors.dart';
import 'package:sabtawya/core/utils/haptics.dart';
import 'package:sabtawya/core/widgets/class_group_header.dart';
import 'package:sabtawya/core/widgets/motion.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/children/child_tile.dart';

Widget _rtl(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

Child _child(String id) => Child(
      id: id,
      classId: 'class-1',
      fullName: 'مينا عادل',
      gender: Gender.boy,
      isActive: true,
      mobile: '01012345678',
    );

void main() {
  test('status tints: success and danger use their own, others a wash', () {
    expect(statusTint(AppColors.success), AppColors.successTint);
    expect(statusTint(AppColors.danger), AppColors.dangerTint);
    expect(statusTint(AppColors.navy).a, closeTo(0.12, 0.01));
  });

  test('haptics never throw', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    Haptics.tap();
    Haptics.select();
    Haptics.success();
    Haptics.warn();
  });

  test('class accent is stable and from the palette', () {
    expect(classAccent('class-1'), classAccent('class-1'));
    expect(classPalette, contains(classAccent('anything')));
  });

  testWidgets('AnimatedCount ends on the value', (tester) async {
    await tester.pumpWidget(_rtl(const AnimatedCount(value: 7)));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
    await tester.pumpWidget(_rtl(const AnimatedCount(value: 12)));
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('ClassGroupHeader paints the bar in the given accent',
      (tester) async {
    await tester.pumpWidget(_rtl(const ClassGroupHeader(
      name: 'فصل',
      count: 3,
      accent: AppColors.maroon,
    )));
    final bars = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == AppColors.maroon);
    expect(bars, isNotEmpty);
  });

  testWidgets('swiping a child row opens contact and the row stays',
      (tester) async {
    var asked = 0;
    await tester.pumpWidget(_rtl(ChildTile(
      child: _child('a'),
      onTap: () {},
      onContact: () => asked++,
    )));
    await tester.fling(find.byType(ChildTile), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(find.byType(ChildTile), findsOneWidget);
  });
}
