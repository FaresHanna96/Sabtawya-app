import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/announcement.dart';
import 'package:sabtawya/data/models/profile.dart';
import 'package:sabtawya/data/repositories/announcement_repository.dart';
import 'package:sabtawya/features/announcements/servant_picker_sheet.dart';

Profile _p(String id, String name) => Profile.fromMap(
    {'id': id, 'full_name': name, 'role': 'servant', 'is_active': true});

void main() {
  group('what is sent', () {
    test('the chosen people go only with their audience', () {
      final people = AnnouncementRepository.sendParams(
        title: ' ع ',
        body: 'نص',
        audience: AnnouncementAudience.people,
        classIds: ['c1'],
        servantIds: ['s1', 's2'],
      );
      expect(people['p_audience'], 'people');
      expect(people['p_servant_ids'], ['s1', 's2']);
      expect(people['p_class_ids'], isEmpty);
      expect(people['p_title'], 'ع');

      for (final a in AnnouncementAudience.values) {
        if (a == AnnouncementAudience.people) continue;
        final p = AnnouncementRepository.sendParams(
            title: 'ع', body: 'ن', audience: a, servantIds: ['s1']);
        expect(p.containsKey('p_servant_ids'), isFalse, reason: a.value);
      }
    });
  });

  group('the list says who it went to', () {
    Announcement sent(List<String> names) => Announcement.fromMap({
          'id': 'a',
          'title': 'ع',
          'body': 'ن',
          'audience': 'people',
          'created_at': '2026-11-26T10:00:00Z',
          'recipients': names.length,
          'read_count': 0,
          'servant_names': names,
        });

    test('up to three names, then how many more', () {
      expect(sent(['أ', 'ب']).audienceLabel, 'أ، ب');
      expect(sent(['أ', 'ب', 'ج', 'د', 'ه']).audienceLabel,
          'أ، ب، ج ${AppStrings.andOthers(2)}');
    });

    test('an old row without names shows the audience word', () {
      expect(sent([]).audienceLabel, AppStrings.audiencePeople);
    });
  });

  group('picking by name', () {
    Future<Set<String>?> run(
      WidgetTester t,
      Future<void> Function() act, {
      Set<String> selected = const {},
    }) async {
      Set<String>? result;
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showServantPicker(
                    context,
                    servants: [_p('1', 'مينا فادي'), _p('2', 'مريم عادل')],
                    selected: selected,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await act();
      await t.pumpAndSettle();
      return result;
    }

    testWidgets('search, tick, and take the choice', (t) async {
      final r = await run(t, () async {
        await t.enterText(find.byType(TextField), 'مريم');
        await t.pump();
        expect(find.text('مينا فادي'), findsNothing);
        await t.tap(find.text('مريم عادل'));
        await t.pump();
        await t.tap(find.textContaining(AppStrings.peopleDone));
      });
      expect(r, {'2'});
    });

    testWidgets('keeps the earlier choice and can drop it', (t) async {
      final r = await run(
        t,
        () async {
          await t.tap(find.text('مينا فادي'));
          await t.pump();
          await t.tap(find.textContaining(AppStrings.peopleDone));
        },
        selected: {'1', '2'},
      );
      expect(r, {'2'});
    });

    testWidgets('a name nobody has', (t) async {
      await run(t, () async {
        await t.enterText(find.byType(TextField), 'زززز');
        await t.pump();
        expect(find.text(AppStrings.noServantMatch), findsOneWidget);
      });
    });
  });
}
