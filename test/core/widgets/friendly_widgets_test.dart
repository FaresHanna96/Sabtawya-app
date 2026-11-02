import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/widgets/app_widgets.dart';
import 'package:sabtawya/core/widgets/celebration.dart';
import 'package:sabtawya/core/widgets/illustrations.dart';
import 'package:sabtawya/core/widgets/motion.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('EmptyState picks an illustration from its icon', (tester) async {
    await tester.pumpWidget(_wrap(const EmptyState(
      icon: Icons.cake_outlined,
      title: 'لا يوجد',
      body: 'نص',
    )));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(Illustration), findsOneWidget);
    expect(find.text('لا يوجد'), findsOneWidget);
    expect(EmptyState.kindForIcon(Icons.cake_outlined),
        IllustrationKind.birthdays);
    expect(EmptyState.kindForIcon(Icons.help), IllustrationKind.generic);
  });

  testWidgets('ErrorView shows the message and retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(ErrorView(
      message: 'خطأ',
      onRetry: () => retried = true,
    )));
    await tester.pump();

    expect(find.byType(Illustration), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    expect(retried, isTrue);
  });

  testWidgets('FadeSlideIn ends fully visible', (tester) async {
    await tester.pumpWidget(_wrap(const FadeSlideIn(
      index: 3,
      child: Text('مرحبا'),
    )));
    await tester.pump(const Duration(seconds: 2));

    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, 1);
    expect(find.text('مرحبا'), findsOneWidget);
  });

  testWidgets('StatCard counts up to its value and reacts to taps',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(StatCard(
      label: 'الأطفال',
      value: '12',
      icon: Icons.groups_outlined,
      onTap: () => taps++,
    )));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('12'), findsOneWidget);
    await tester.tap(find.byType(StatCard));
    expect(taps, 1);
  });

  testWidgets('GreetingBanner greets by name', (tester) async {
    await tester.pumpWidget(_wrap(const GreetingBanner(name: 'مينا')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('مينا'), findsOneWidget);
  });

  testWidgets('Celebration shows confetti and removes itself', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_wrap(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));

    Celebration.show(ctx);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CustomPaint), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('SectionCard shows its icon badge', (tester) async {
    await tester.pumpWidget(_wrap(const SectionCard(
      title: 'عنوان',
      icon: Icons.star_rounded,
      accent: Colors.orange,
      child: Text('محتوى'),
    )));
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.text('عنوان'), findsOneWidget);
  });
}
