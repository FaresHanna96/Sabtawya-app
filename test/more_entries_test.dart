import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/features/home/more_entries.dart';

Set<String> _ids(Iterable<MoreEntry> e) => {for (final x in e) x.id};

void main() {
  group('who sees what', () {
    test('a general servant has no import, export or admin entries', () {
      final ids = _ids(MoreCatalog.entriesFor(MoreRole.generalServant));
      expect(ids, isNot(contains('import')));
      expect(ids, isNot(contains('export')));
      expect(ids, isNot(contains('servants')));
      expect(ids, contains('competitions'));
      expect(ids, contains('servantDirectory'));
    });

    test('a class servant can import but has no competitions', () {
      final ids = _ids(MoreCatalog.entriesFor(MoreRole.servant));
      expect(ids, contains('import'));
      expect(ids, isNot(contains('competitions')));
      expect(ids, isNot(contains('activityLog')));
      expect(ids, contains('servantDirectory'));
    });

    test('an admin has everything but the servant directory', () {
      final ids = _ids(MoreCatalog.entriesFor(MoreRole.admin));
      expect(ids, isNot(contains('servantDirectory')));
      expect(
        ids,
        containsAll(['import', 'competitions', 'servants', 'activityLog']),
      );
    });

    test('التحضيرات is for the admin, in the grid, with its badge', () {
      final top = _ids(MoreCatalog.topFor(MoreRole.admin));
      expect(top, contains('preps'));
      for (final role in [MoreRole.servant, MoreRole.generalServant]) {
        expect(_ids(MoreCatalog.entriesFor(role)), isNot(contains('preps')));
      }
      final preps = MoreCatalog.all.firstWhere((e) => e.id == 'preps');
      expect(preps.count, MoreCount.pendingPreps);
      // The activities it replaced in the grid are still a row below.
      final below = [
        for (final (_, rows) in MoreCatalog.groupsFor(MoreRole.admin)) ...rows
      ];
      expect(_ids(below), contains('events'));
    });

    test('everyone can check for updates, under التطبيق', () {
      for (final role in MoreRole.values) {
        final groups = MoreCatalog.groupsFor(role);
        final app = groups.firstWhere((g) => g.$1 == MoreGroup.app).$2;
        expect(_ids(app), contains(MoreCatalog.updatesId), reason: '$role');
      }
      final entry =
          MoreCatalog.all.firstWhere((e) => e.id == MoreCatalog.updatesId);
      expect(entry.open, isNull); // an action المزيد runs, not a screen
    });

    test('no two entries share an icon', () {
      final icons = [for (final e in MoreCatalog.all) e.icon];
      expect(icons.toSet().length, icons.length);
    });
  });

  group('grid and groups', () {
    for (final role in MoreRole.values) {
      test('$role: six in the grid, none repeated below, no lone row', () {
        final top = MoreCatalog.topFor(role);
        expect(top, hasLength(6));
        final groups = MoreCatalog.groupsFor(role);
        final below = [for (final (_, rows) in groups) ...rows];
        expect(_ids(below).intersection(_ids(top)), isEmpty);
        // A card is never a single row under its own title.
        for (final (group, rows) in groups) {
          expect(rows.length, greaterThanOrEqualTo(2), reason: '$group');
        }
        // Grid plus groups is every entry the role sees, once each.
        expect(
          top.length + below.length,
          MoreCatalog.entriesFor(role).length,
        );
      });
    }

    test('the admin group is only for the admin', () {
      for (final role in [MoreRole.servant, MoreRole.generalServant]) {
        final groups = [for (final (g, _) in MoreCatalog.groupsFor(role)) g];
        expect(groups, isNot(contains(MoreGroup.admin)));
      }
    });
  });

  group('search', () {
    final all = MoreCatalog.entriesFor(MoreRole.admin);

    test('an empty query keeps everything', () {
      expect(MoreCatalog.search(all, '  '), all);
    });

    test('finds by keyword', () {
      expect(_ids(MoreCatalog.search(all, 'غياب')), contains('absence'));
      expect(
        _ids(MoreCatalog.search(all, 'اكسل')),
        containsAll(['import', 'export']),
      );
    });

    test('letter variants match: أ/ا and ة/ه', () {
      expect(_ids(MoreCatalog.search(all, 'اعياد')), contains('birthdays'));
      expect(_ids(MoreCatalog.search(all, 'المزامنه')), contains('sync'));
      expect(
        _ids(MoreCatalog.search(all, 'تحديث')),
        contains(MoreCatalog.updatesId),
      );
    });

    test('every word must match', () {
      expect(
        _ids(MoreCatalog.search(all, 'سجل حضور')),
        {'attendanceHistory'},
      );
      expect(MoreCatalog.search(all, 'شيء مش موجود'), isEmpty);
    });
  });
}
