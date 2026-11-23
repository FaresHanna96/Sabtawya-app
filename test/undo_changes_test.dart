import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/utils/child_changes.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/models/import_batch.dart';
import 'package:sabtawya/features/children/change_history_card.dart';

ChildChange _edit(
  int id,
  String at, {
  Map<String, ({Object? before, Object? after})> values = const {},
}) =>
    ChildChange(
      id: id,
      createdAt: DateTime.parse(at),
      action: 'update',
      entity: 'children',
      actorName: 'فارس',
      changed: values.keys.toList(),
      values: values,
    );

void main() {
  group('grouping keeps the log ids to undo', () {
    test('one day, one person: every id, newest first', () {
      final g = groupChanges([
        _edit(12, '2026-11-13T12:00:00',
            values: {'mother_mobile': (before: '1', after: '2')}),
        _edit(11, '2026-11-13T09:00:00',
            values: {'address': (before: 'أ', after: 'ب')}),
      ]);
      expect(g, hasLength(1));
      expect(g.single.ids, [12, 11]);
      expect(g.single.canUndo, isTrue);
    });

    test('an old entry without values cannot be undone', () {
      final g = groupChanges([
        _edit(5, '2026-11-13T09:00:00'),
      ]);
      expect(g.single.ids, isEmpty);
      expect(g.single.canUndo, isFalse);
    });

    test('a photo-only change cannot be undone, attendance and adding neither',
        () {
      final photo = groupChanges([
        _edit(7, '2026-11-13T09:00:00',
            values: {'photo_path': (before: null, after: 'x.jpg')}),
      ]);
      expect(photo.single.canUndo, isFalse);

      final added = groupChanges([
        ChildChange(
            id: 1,
            createdAt: DateTime.parse('2026-11-13T09:00:00'),
            action: 'insert',
            entity: 'children'),
      ]);
      expect(added.single.canUndo, isFalse);

      final attendance = groupChanges([
        ChildChange(
            id: 2,
            createdAt: DateTime.parse('2026-11-13T09:00:00'),
            action: 'update',
            entity: 'attendance_records'),
      ]);
      expect(attendance.single.canUndo, isFalse);
    });

    test('the log id is read from the database row', () {
      final c = ChildChange.fromMap({
        'id': 42,
        'created_at': '2026-11-13T09:00:00Z',
        'action': 'update',
        'entity': 'children',
        'changed': ['address'],
        'changes': {
          'address': {'old': 'أ', 'new': 'ب'}
        },
      });
      expect(c.id, 42);
    });
  });

  group('the history card', () {
    Widget app(Future<void> Function(ChildChangeGroup)? onUndo) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ChangeHistoryCard(
                  now: DateTime(2026, 11, 14),
                  onUndo: onUndo,
                  changes: [
                    _edit(9, '2026-11-13T09:00:00',
                        values: {'address': (before: 'أ', after: 'ب')}),
                  ],
                ),
              ),
            ),
          ),
        );

    testWidgets('shows an undo button that hands over the line',
        (tester) async {
      ChildChangeGroup? asked;
      await tester.pumpWidget(app((g) async => asked = g));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.changeHistory));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تراجع'));
      expect(asked?.ids, [9]);
    });

    testWidgets('no undo button without permission', (tester) async {
      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.changeHistory));
      await tester.pumpAndSettle();
      expect(find.text('أ'), findsNothing, reason: 'values are shown as text');
      expect(find.text('تراجع'), findsNothing);
    });
  });

  group('recent imports', () {
    test('reads a batch', () {
      final b = ImportBatch.fromMap({
        'id': 'b1',
        'created_at': '2026-11-17T10:00:00Z',
        'actor_name': 'فارس',
        'inserted': 3,
        'updated': 2,
      });
      expect(b.inserted, 3);
      expect(b.updated, 2);
      expect(b.actorName, 'فارس');
    });
  });
}
