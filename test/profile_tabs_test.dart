import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/features/children/profile/profile_tabs.dart';

Widget _app() => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: DefaultTabController(
            length: 2,
            child: ProfileTabs(
              onRefresh: () async {},
              header: const SizedBox(height: 300, child: Text('head')),
              tabBar: const TabBar(tabs: [Tab(text: 'one'), Tab(text: 'two')]),
              tabs: [
                [
                  for (var i = 0; i < 30; i++)
                    SizedBox(height: 60, child: Text('first $i')),
                ],
                const [SizedBox(height: 60, child: Text('second 0'))],
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a tab opened after scrolling starts below the pinned bar',
      (tester) async {
    await tester.pumpWidget(_app());
    // Scroll the first tab until the header is gone.
    await tester.drag(find.text('first 3'), const Offset(0, -700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('two'));
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byType(TabBar));
    final first = tester.getRect(find.text('second 0'));
    expect(first.top, greaterThanOrEqualTo(bar.bottom));
  });

  testWidgets('at the top, the first card is just under the bar',
      (tester) async {
    await tester.pumpWidget(_app());
    final bar = tester.getRect(find.byType(TabBar));
    final first = tester.getRect(find.text('first 0'));
    expect(first.top - bar.bottom, closeTo(12, 1));
  });

  testWidgets('each tab keeps its own place', (tester) async {
    await tester.pumpWidget(_app());
    await tester.drag(find.text('first 3'), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('first 0').hitTestable(), findsNothing);
    await tester.tap(find.text('two'));
    await tester.pumpAndSettle();
    expect(find.text('second 0').hitTestable(), findsOneWidget);
    await tester.tap(find.text('one'));
    await tester.pumpAndSettle();
    expect(find.text('first 0').hitTestable(), findsNothing); // still scrolled
  });

  testWidgets('a folding card works after the tab was scrolled',
      (tester) async {
    // A folding card saves "open" in the same page storage the tab's scroll
    // position uses: without its own slot it read a number as yes/no and the
    // whole tab went grey.
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: DefaultTabController(
            length: 2,
            child: ProfileTabs(
              onRefresh: () async {},
              header: const SizedBox(height: 300),
              tabBar: const TabBar(tabs: [Tab(text: 'one'), Tab(text: 'two')]),
              tabs: [
                [
                  for (var i = 0; i < 30; i++)
                    SizedBox(height: 60, child: Text('first $i')),
                ],
                const [
                  ExpansionTile(
                      title: Text('fold'), children: [Text('inside')]),
                ],
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.drag(find.text('first 3'), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('two'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('fold'));
    await tester.pumpAndSettle();
    expect(find.text('inside'), findsOneWidget);
    // Leave and come back: nothing breaks, and the card still folds.
    await tester.tap(find.text('one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('two'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('fold'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a notes box inside a folding card opens without breaking',
      (tester) async {
    // A multi-line text box scrolls, so it also reads page storage: it must not
    // see the "open" flag its folding card saved.
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: DefaultTabController(
            length: 1,
            child: ProfileTabs(
              onRefresh: () async {},
              header: const SizedBox(height: 100),
              tabBar: const TabBar(tabs: [Tab(text: 'one')]),
              tabs: const [
                [
                  ExpansionTile(
                    title: Text('fold'),
                    children: [TextField(maxLines: 2)],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('fold'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });
}
