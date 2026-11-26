import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/widgets/unsaved_changes_guard.dart';
import 'package:sabtawya/features/home/app_nav_bar.dart';
import 'package:sabtawya/features/home/shell_frame.dart';

const _labels = [
  'الرئيسية',
  'الفصول',
  'المخدومين',
  'الحضور',
  'متابعة الخدام',
  'المزيد',
];

class _Harness extends StatefulWidget {
  const _Harness({this.guarded = false, this.wide = false});

  final bool guarded;
  final bool wide;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final _pages = GlobalKey<NavigatorState>();
  int _index = 0;

  void _open(BuildContext context) => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => UnsavedChangesGuard(
            dirty: widget.guarded,
            child: Scaffold(
              appBar: AppBar(title: const Text('sub')),
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => _open(context),
                  child: const Text('deeper'),
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget bar(ValueChanged<int> select) => AppNavBar(
          selectedIndex: _index,
          onSelected: select,
          items: [
            for (final label in _labels)
              AppNavItem(
                label: label,
                color: Colors.teal,
                icon: const Icon(Icons.circle_outlined),
                selectedIcon: const Icon(Icons.circle),
              ),
          ],
        );
    return ShellFrame(
      navigatorKey: _pages,
      onSelect: (i) => setState(() => _index = i),
      bottomBar: widget.wide ? null : bar,
      sideMenu: widget.wide
          ? (select) => TextButton(
                onPressed: () => select(1),
                child: const Text('side'),
              )
          : null,
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              Text('tab $_index'),
              TextButton(
                onPressed: () => _open(context),
                child: const Text('open'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    builder: (context, app) =>
        Directionality(textDirection: TextDirection.rtl, child: app!),
    home: child,
  ));
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the bar stays on pages and sub-pages', (tester) async {
    await _pump(tester, const _Harness());
    await _tap(tester, 'open');
    expect(find.text('sub'), findsOneWidget);
    expect(find.byType(AppNavBar), findsOneWidget);
    await _tap(tester, 'deeper');
    expect(find.byType(AppNavBar), findsOneWidget);
  });

  testWidgets('another tab closes every page and shows that tab',
      (tester) async {
    await _pump(tester, const _Harness());
    await _tap(tester, 'open');
    await _tap(tester, 'deeper');
    await _tap(tester, 'المخدومين');
    expect(find.text('sub'), findsNothing);
    expect(find.text('tab 2'), findsOneWidget);
  });

  testWidgets('the current tab goes back to its first page', (tester) async {
    await _pump(tester, const _Harness());
    await _tap(tester, 'open');
    await _tap(tester, 'الرئيسية');
    expect(find.text('sub'), findsNothing);
    expect(find.text('tab 0'), findsOneWidget);
  });

  testWidgets('the phone\'s back button goes back one page', (tester) async {
    await _pump(tester, const _Harness());
    await _tap(tester, 'open');
    await _tap(tester, 'deeper');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('sub'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('tab 0'), findsOneWidget);
    expect(find.text('sub'), findsNothing);
  });

  testWidgets('unsaved changes: the tab changes only after confirming',
      (tester) async {
    await _pump(tester, const _Harness(guarded: true));
    await _tap(tester, 'open');

    await _tap(tester, 'الفصول');
    expect(find.text(AppStrings.unsavedChanges), findsOneWidget);
    // Keep editing: still on the page, and the tab is forgotten.
    await _tap(tester, AppStrings.cancel);
    expect(find.text('sub'), findsOneWidget);

    await _tap(tester, 'الحضور');
    await _tap(tester, AppStrings.discard);
    expect(find.text('sub'), findsNothing);
    expect(find.text('tab 3'), findsOneWidget);
  });

  testWidgets('the keyboard hides the bar and keeps the page', (tester) async {
    await _pump(tester, const _Harness());
    await _tap(tester, 'open');
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    expect(find.byType(AppNavBar), findsNothing);
    expect(find.text('sub'), findsOneWidget);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(AppNavBar), findsOneWidget);
    expect(find.text('sub'), findsOneWidget);
  });

  testWidgets('wide screens keep the side menu on pages', (tester) async {
    await _pump(tester, const _Harness(wide: true));
    await _tap(tester, 'open');
    expect(find.text('side'), findsOneWidget);
    await _tap(tester, 'side');
    expect(find.text('tab 1'), findsOneWidget);
  });

  testWidgets('six tabs fit a small phone at large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      const MediaQuery(
        data: MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: _Harness(),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final label in _labels) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
