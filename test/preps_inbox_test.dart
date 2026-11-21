import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/servant_activity.dart';
import 'package:sabtawya/features/servant_activities/preps_inbox_screen.dart';

LessonPrep _prep(
  String id, {
  String status = 'pending',
  required DateTime saturday,
  required DateTime sent,
}) =>
    LessonPrep(
      id: id,
      servantId: 's-$id',
      servantName: 'خادم $id',
      sessionId: 'session',
      sessionDate: saturday,
      status: status,
      photos: const [],
      createdAt: sent,
    );

void main() {
  final sat1 = DateTime(2026, 11, 7);
  final sat2 = DateTime(2026, 11, 14);

  final a = _prep('a', saturday: sat1, sent: DateTime(2026, 11, 6, 20));
  final b = _prep('b',
      status: 'accepted', saturday: sat1, sent: DateTime(2026, 11, 6, 21));
  final c = _prep('c', saturday: sat2, sent: DateTime(2026, 11, 13, 9));
  final d = _prep('d',
      status: 'commented', saturday: sat2, sent: DateTime(2026, 11, 13, 22));

  List<String> ids(Iterable<LessonPrep> l) => [for (final p in l) p.id];

  test('merge keeps each prep once, the latest sent first', () {
    // A waiting prep can also be among the recent ones.
    final all = PrepsInbox.merge([a, c], [d, c, b]);
    expect(ids(all), ['d', 'c', 'b', 'a']);
  });

  test('filters: waiting, reviewed (accepted or commented), all', () {
    final all = [a, b, c, d];
    expect(ids(PrepsInbox.filter(all, PrepsFilter.pending)), ['a', 'c']);
    expect(ids(PrepsInbox.filter(all, PrepsFilter.reviewed)), ['b', 'd']);
    expect(PrepsInbox.filter(all, PrepsFilter.all), hasLength(4));
  });

  test('grouped by Saturday, the latest Saturday first, order kept inside', () {
    final groups = PrepsInbox.bySaturday([b, a, d, c]);
    expect([for (final (day, _) in groups) day], [sat2, sat1]);
    expect(ids(groups[0].$2), ['d', 'c']);
    expect(ids(groups[1].$2), ['b', 'a']);
  });

  test('a review run goes first come, first served', () {
    expect(ids(PrepsInbox.runOrder([c, a])), ['a', 'c']);
  });

  test('a prep with no send time goes first in a run, not lost', () {
    final old = LessonPrep(
      id: 'old',
      servantId: 's',
      servantName: 'x',
      sessionId: 'y',
      sessionDate: sat1,
      status: 'pending',
      photos: const [],
    );
    expect(ids(PrepsInbox.runOrder([c, old])), ['old', 'c']);
  });

  testWidgets('a row shows who and which class, and no "0 files"',
      (tester) async {
    final prep = LessonPrep(
      id: 'r',
      servantId: 's',
      servantName: 'مينا فايز',
      sessionId: 'x',
      sessionDate: sat2,
      status: 'pending',
      photos: const [],
      className: '3 ولاد',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PrepInboxRow(prep: prep, onTap: () {})),
    ));
    expect(find.text('مينا فايز'), findsOneWidget);
    expect(find.textContaining('3 ولاد'), findsOneWidget);
    expect(find.textContaining('ملفات'), findsNothing);
    expect(find.textContaining('ملف'), findsNothing);
  });
}
