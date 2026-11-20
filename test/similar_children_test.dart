import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/services/child_import_service.dart';
import 'package:sabtawya/data/services/excel_service.dart';
import 'package:sabtawya/features/announcements/announcement_dialog.dart';
import 'package:sabtawya/features/children/similar_children_dialog.dart';

SimilarChild match(String id, String cls, {String reason = 'same_name'}) =>
    SimilarChild(
      key: '',
      childId: id,
      fullName: 'مينا عادل فؤاد',
      classId: cls,
      className: 'فصل $cls',
      isActive: true,
      reason: reason,
    );

Future<SimilarChoice?> openDialog(
  WidgetTester tester,
  List<SimilarChild> matches,
  bool Function(String) canOpen,
) async {
  SimilarChoice? choice;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          choice =
              await showSimilarChildrenDialog(context, matches, canOpen: canOpen);
        },
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return choice;
}

void main() {
  group('similar children dialog', () {
    testWidgets('lists each match with its class and why it matched',
        (tester) async {
      await openDialog(
        tester,
        [match('a', '5'), match('b', '6', reason: 'same_first_and_phone')],
        (_) => false,
      );
      expect(find.text('مينا عادل فؤاد'), findsNWidgets(2));
      expect(find.textContaining('فصل 5'), findsOneWidget);
      expect(find.textContaining(AppStrings.similarReason('same_first_and_phone')),
          findsOneWidget);
    });

    testWidgets('"فتح الملف" only for a class the person can see',
        (tester) async {
      await openDialog(tester, [match('a', 'mine'), match('b', 'other')],
          (cls) => cls == 'mine');
      expect(find.text(AppStrings.similarOpen), findsOneWidget);
    });

    testWidgets('save anyway, back and open return their choice',
        (tester) async {
      SimilarChoice? choice;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              choice = await showSimilarChildrenDialog(
                  context, [match('a', 'mine')],
                  canOpen: (_) => true);
            },
            child: const Text('open'),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.similarSaveAnyway));
      await tester.pumpAndSettle();
      expect(choice, isA<SaveAnyway>());

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.similarBack));
      await tester.pumpAndSettle();
      expect(choice, isA<GoBack>());

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.similarOpen));
      await tester.pumpAndSettle();
      expect(choice, isA<OpenExisting>());
      expect((choice! as OpenExisting).childId, 'a');
    });
  });

  group('import plan with look-alikes', () {
    ImportRow row(int n, {List<SimilarChild> similar = const []}) =>
        ImportRow(rowNumber: n, name: 'طفل $n', gender: Gender.boy)
          ..action = ImportAction.insert
          ..similar = similar;

    test('a look-alike counts as a warning and is still added', () {
      final plan = ImportPlan(
        rows: [row(1), row(2, similar: [match('a', '5')])],
        classId: 'c',
        mode: ImportMode.addNew,
      );
      expect(plan.insertCount, 2);
      expect(plan.lookAlikeCount, 1);
      expect(plan.hasWork, isTrue);
    });

    test('"لا تضف" leaves the row out of the inserts', () {
      final flagged = row(2, similar: [match('a', '5')])..skipLookAlike = true;
      final plan = ImportPlan(
        rows: [row(1), flagged],
        classId: 'c',
        mode: ImportMode.addNew,
      );
      expect(plan.insertCount, 1);
      expect(plan.lookAlikeCount, 0);
    });

    test('resolving again clears the match but keeps the person\'s tick', () {
      final r = row(1, similar: [match('a', '5')])..skipLookAlike = true;
      r.resetResolution();
      expect(r.similar, isEmpty);
      expect(r.skipLookAlike, isTrue);
    });

    test('the query sends only usable numbers', () {
      final json = const SimilarQuery(
        key: '3',
        name: 'مينا',
        mobiles: ['01011111111', null, '  '],
      ).toJson();
      expect(json['mobiles'], ['01011111111']);
      expect(json['key'], '3');
    });
  });

  testWidgets('an announcement opens with its whole text', (tester) async {
    final body = 'سطر ' * 80;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showAnnouncementDialog(
            context,
            title: 'اجتماع الخدام',
            body: body,
            sentAt: DateTime.now(),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('اجتماع الخدام'), findsOneWidget);
    expect(find.text(body), findsOneWidget);
    await tester.tap(find.text(AppStrings.close));
    await tester.pumpAndSettle();
    expect(find.text('اجتماع الخدام'), findsNothing);
  });
}
