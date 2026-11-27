import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/children/ask_family.dart';
import 'package:sabtawya/features/children/asked_log.dart';
import 'package:sabtawya/features/children/missing_info_banner.dart';

Child _child({
  String id = 'k',
  bool noBirth = false,
  String? mobile = '01011111111',
  String? motherMobile,
  String? fatherMobile,
}) =>
    Child(
      id: id,
      classId: 'c',
      fullName: 'مينا',
      gender: Gender.boy,
      isActive: true,
      birthDate: noBirth ? null : DateTime(2016, 3, 9),
      mobile: mobile,
      motherName: 'أم',
      motherMobile: motherMobile,
      fatherName: 'أب',
      fatherMobile: fatherMobile,
      confessionFather: 'أبونا',
      school: 'مدرسة',
      address: 'مدينة نصر',
    );

void main() {
  late AskedLog log;

  setUp(() => log = AskedLog.memory());

  group('the asked log', () {
    test('remembers when a family was asked, and nobody else', () async {
      expect(await log.when('a'), isNull);
      await log.mark('a', at: DateTime(2026, 11, 10));
      expect(await log.when('a'), DateTime(2026, 11, 10));
      expect(await log.when('b'), isNull);
      expect(await log.all(), {'a': DateTime(2026, 11, 10)});
    });

    test('is kept in the Hive box on disk', () async {
      final dir = Directory.systemTemp.createTempSync('asked');
      addTearDown(() async {
        await Hive.close();
        dir.deleteSync(recursive: true);
      });
      Hive.init(dir.path);
      final disk = AskedLog(open: () => Hive.openBox<dynamic>('asked_test'));
      await disk.mark('a', at: DateTime(2026, 11, 10));
      expect(await disk.when('a'), DateTime(2026, 11, 10));
      expect(await disk.all(), {'a': DateTime(2026, 11, 10)});
    });

    test('counts whole days and calls a week old news', () {
      final now = DateTime(2026, 11, 16, 9);
      expect(AskedLog.daysAgo(DateTime(2026, 11, 16, 23), now), 0);
      expect(AskedLog.daysAgo(DateTime(2026, 11, 13), now), 3);
      expect(AskedLog.daysAgo(null, now), isNull);
      expect(AskedLog.isRecent(DateTime(2026, 11, 10), now), isTrue);
      expect(AskedLog.isRecent(DateTime(2026, 11, 9), now), isFalse);
      expect(AskedLog.isRecent(null, now), isFalse);
    });
  });

  group('asking the family', () {
    Future<(bool, List<Uri>)> ask(
      WidgetTester tester,
      Child child, {
      String? tap,
    }) async {
      final opened = <Uri>[];
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await askFamilyOnWhatsApp(
                  context,
                  child,
                  servantName: 'أبانوب',
                  log: log,
                  now: DateTime(2026, 11, 16),
                  launch: (u) async {
                    opened.add(u);
                    return true;
                  },
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      if (tap != null) {
        await tester.tap(find.text(tap));
        await tester.pumpAndSettle();
      }
      return (result ?? false, opened);
    }

    testWidgets('a first ask opens WhatsApp with only the missing fields',
        (tester) async {
      final out = await ask(tester, _child(noBirth: true));
      expect(out.$1, isTrue);
      expect(out.$2, hasLength(1));
      final text = out.$2.single.queryParameters['text']!;
      expect(text, contains('تاريخ الميلاد'));
      expect(text, isNot(contains('العنوان')));
      final saved = await log.when('k');
      expect(saved, DateTime(2026, 11, 16));
    });

    testWidgets('a family asked 3 days ago is asked about first',
        (tester) async {
      await log.mark('k', at: DateTime(2026, 11, 13));
      final out = await ask(tester, _child(noBirth: true));
      expect(out.$1, isFalse);
      expect(out.$2, isEmpty);
      expect(find.text('اتطلب من 3 أيام'), findsOneWidget);
    });

    testWidgets('yes sends again', (tester) async {
      await log.mark('k', at: DateTime(2026, 11, 13));
      final out = await ask(tester, _child(noBirth: true), tap: 'ابعت تاني');
      expect(out.$1, isTrue);
      expect(out.$2, hasLength(1));
    });

    testWidgets('nothing to ask, or nobody to ask, does nothing',
        (tester) async {
      final complete = await ask(tester, _child());
      expect(complete.$1, isFalse);
      expect(complete.$2, isEmpty);

      final nobody = await ask(tester, _child(noBirth: true, mobile: null));
      expect(nobody.$1, isFalse);
      expect(nobody.$2, isEmpty);
    });
  });

  group('the banner on a child page', () {
    Widget app({required bool canEdit, Child? child, VoidCallback? onEdit}) =>
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: MissingInfoBanner(
                child: child ?? _child(noBirth: true),
                servantName: 'أبانوب',
                canEdit: canEdit,
                onEdit: onEdit ?? () {},
                log: log,
              ),
            ),
          ),
        );

    testWidgets('names what is missing, with ask and fill-in buttons',
        (tester) async {
      await tester.pumpWidget(app(canEdit: true));
      await tester.pumpAndSettle();
      expect(find.text('ناقص: تاريخ الميلاد'), findsOneWidget);
      expect(
          find.byTooltip('اطلب البيانات من الأسرة على واتساب'), findsOneWidget);
      expect(find.byTooltip('كمّل البيانات'), findsOneWidget);
    });

    testWidgets('the fill-in button opens the form', (tester) async {
      var edits = 0;
      await tester.pumpWidget(app(canEdit: true, onEdit: () => edits++));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('كمّل البيانات'));
      expect(edits, 1);
    });

    testWidgets('hidden for who may not edit, and when nothing is missing',
        (tester) async {
      await tester.pumpWidget(app(canEdit: false));
      await tester.pumpAndSettle();
      expect(find.textContaining('ناقص'), findsNothing);

      await tester.pumpWidget(app(canEdit: true, child: _child()));
      await tester.pumpAndSettle();
      expect(find.textContaining('ناقص'), findsNothing);
    });

    testWidgets('no ask button when there is nobody to write to',
        (tester) async {
      await tester.pumpWidget(app(
        canEdit: true,
        child: _child(noBirth: true, mobile: null),
      ));
      await tester.pumpAndSettle();
      expect(
          find.byTooltip('اطلب البيانات من الأسرة على واتساب'), findsNothing);
      expect(find.byTooltip('كمّل البيانات'), findsOneWidget);
    });

    testWidgets('says when the family was asked', (tester) async {
      await tester.runAsync(() =>
          log.mark('k', at: DateTime.now().subtract(const Duration(days: 2))));
      await tester.pumpWidget(app(canEdit: true));
      await tester.pumpAndSettle();
      expect(find.text('اتطلب من يومين'), findsOneWidget);
    });
  });
}
