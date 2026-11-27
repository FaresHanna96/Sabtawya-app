// Checks of the database's own rules (row security, triggers, functions) against
// the DEV Supabase project, with its three test accounts. Not part of
// `flutter test`; run it on purpose:
//
//   flutter test test_dev
//
// It needs backups/dev-credentials.txt and backups/dev-publishable-key.txt
// (git-ignored). Without them every test is skipped. Each test puts back what
// it changed. Never point this at production.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _base = 'https://atusdmohomycgqmhoovh.supabase.co';
const _backups = 'backups';

String? _key;
final _accounts = <String, (String, String)>{};

void _loadCredentials() {
  final keyFile = File('$_backups/dev-publishable-key.txt');
  final credFile = File('$_backups/dev-credentials.txt');
  if (!keyFile.existsSync() || !credFile.existsSync()) return;
  _key = keyFile.readAsStringSync().trim().split(RegExp(r'\s+')).last;
  final line = RegExp(r'^\s*(admin|servant|general)\s+(\S+)\s*/\s*(\S+)');
  for (final l in credFile.readAsLinesSync()) {
    final m = line.firstMatch(l);
    if (m != null) _accounts[m.group(1)!] = (m.group(2)!, m.group(3)!);
  }
}

class _Reply {
  _Reply(this.status, this.body);
  final int status;
  final dynamic body;
  bool get ok => status >= 200 && status < 300;
  List<dynamic> get rows => body is List ? body as List<dynamic> : const [];
  String get code => body is Map ? '${(body as Map)['code']}' : '';
}

Future<_Reply> _call(
  String method,
  String path, {
  String? token,
  Object? body,
  String? prefer,
}) async {
  final request = http.Request(method, Uri.parse('$_base$path'))
    ..headers.addAll({
      'apikey': _key!,
      'Authorization': 'Bearer ${token ?? _key}',
      'Content-Type': 'application/json',
      if (prefer != null) 'Prefer': prefer,
    });
  if (body != null) request.body = jsonEncode(body);
  final response = await http.Response.fromStream(await request.send());
  dynamic decoded;
  try {
    decoded = response.body.isEmpty ? null : jsonDecode(response.body);
  } catch (_) {
    decoded = response.body;
  }
  return _Reply(response.statusCode, decoded);
}

class _Who {
  _Who(this.token, this.id);
  final String token;
  final String id;
}

final _sessions = <String, _Who>{};

Future<_Who> _login(String who) async {
  final cached = _sessions[who];
  if (cached != null) return cached;
  final (email, password) = _accounts[who]!;
  final r = await _call('POST', '/auth/v1/token?grant_type=password',
      body: {'email': email, 'password': password});
  expect(r.status, 200, reason: 'sign in as $who');
  final data = r.body as Map<String, dynamic>;
  return _sessions[who] = _Who(
    data['access_token'] as String,
    (data['user'] as Map<String, dynamic>)['id'] as String,
  );
}

void main() {
  _loadCredentials();
  final skip = _key == null || _accounts.length < 3
      ? 'no dev credentials in $_backups/'
      : null;

  void dev(String name, Future<void> Function() body) => test(name, body,
      skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  final started = DateTime.now().toUtc().toIso8601String();

  tearDownAll(() async {
    if (skip != null) return;
    // The attendance tests make "attendance taken" notifications for admins.
    final admin = await _login('admin');
    await _call('DELETE',
        '/rest/v1/notifications?kind=eq.attendance_taken&created_at=gte.$started',
        token: admin.token);
  });

  group('who sees what', () {
    dev('a servant sees only the children of their own class', () async {
      final servant = await _login('servant');
      final admin = await _login('admin');
      final mine = await _call(
          'GET', '/rest/v1/children?select=id,class_id&is_active=eq.true',
          token: servant.token);
      final all = await _call(
          'GET', '/rest/v1/children?select=id,class_id&is_active=eq.true',
          token: admin.token);

      final myClasses = {for (final c in mine.rows) c['class_id']};
      final allClasses = {for (final c in all.rows) c['class_id']};
      expect(mine.rows, isNotEmpty);
      expect(myClasses.length, lessThan(allClasses.length));
      expect(mine.rows.length, lessThan(all.rows.length));
    });

    dev('an account that is not active reads nothing', () async {
      final servant = await _login('servant');
      final admin = await _login('admin');
      await _call('PATCH', '/rest/v1/profiles?id=eq.${servant.id}',
          token: admin.token, body: {'is_active': false});
      try {
        final children = await _call('GET', '/rest/v1/children?select=id',
            token: servant.token);
        final birthdays = await _call(
            'GET', '/rest/v1/v_servant_birthdays?select=id',
            token: servant.token);
        expect(children.rows, isEmpty);
        expect(birthdays.rows, isEmpty);
      } finally {
        await _call('PATCH', '/rest/v1/profiles?id=eq.${servant.id}',
            token: admin.token, body: {'is_active': true});
      }
    });

    dev('an active servant reads the servants birthdays', () async {
      final servant = await _login('servant');
      final admin = await _login('admin');
      await _call('PATCH', '/rest/v1/profiles?id=eq.${admin.id}',
          token: admin.token, body: {'birth_date': '1990-05-05'});
      try {
        final r = await _call('GET', '/rest/v1/v_servant_birthdays?select=id',
            token: servant.token);
        expect(r.rows.map((x) => x['id']), contains(admin.id));
        final anon =
            await _call('GET', '/rest/v1/v_servant_birthdays?select=id');
        expect(anon.ok && anon.rows.isNotEmpty, isFalse);
      } finally {
        await _call('PATCH', '/rest/v1/profiles?id=eq.${admin.id}',
            token: admin.token, body: {'birth_date': null});
      }
    });
  });

  group('the profile guard', () {
    dev('a servant cannot change role, activation, hiding or the sign-up decision',
        () async {
      final servant = await _login('servant');
      for (final change in <Map<String, Object?>>[
        {'role': 'admin'},
        {'is_active': false},
        {'is_hidden': true},
        {'rejected_at': '2026-01-01T00:00:00Z'},
      ]) {
        final r = await _call('PATCH', '/rest/v1/profiles?id=eq.${servant.id}',
            token: servant.token, body: change);
        expect(r.status, 403, reason: '$change');
      }
      final me = await _call('GET',
          '/rest/v1/profiles?id=eq.${servant.id}&select=role,is_active,is_hidden',
          token: servant.token);
      expect(me.rows.single,
          {'role': 'servant', 'is_active': true, 'is_hidden': false});
    });

    dev('a servant can still edit their own ordinary fields', () async {
      final servant = await _login('servant');
      final now = await _call(
          'GET', '/rest/v1/profiles?id=eq.${servant.id}&select=mobile',
          token: servant.token);
      final r = await _call('PATCH', '/rest/v1/profiles?id=eq.${servant.id}',
          token: servant.token, body: {'mobile': now.rows.single['mobile']});
      expect(r.ok, isTrue);
    });

    dev('an admin can hide and unhide an account', () async {
      final servant = await _login('servant');
      final admin = await _login('admin');
      final a = await _call('PATCH', '/rest/v1/profiles?id=eq.${servant.id}',
          token: admin.token, body: {'is_hidden': true});
      final b = await _call('PATCH', '/rest/v1/profiles?id=eq.${servant.id}',
          token: admin.token, body: {'is_hidden': false});
      expect(a.ok && b.ok, isTrue);
    });
  });

  group('attendance', () {
    late String sessionId;
    late List<String> childIds;

    Future<void> findSession() async {
      final servant = await _login('servant');
      final s = await _call(
          'GET',
          '/rest/v1/attendance_sessions?select=id,class_id&is_locked=eq.false'
              '&order=session_date.desc&limit=1',
          token: servant.token);
      sessionId = s.rows.single['id'] as String;
      final kids = await _call(
          'GET',
          '/rest/v1/children?select=id&class_id=eq.${s.rows.single['class_id']}'
              '&is_active=eq.true&order=full_name&limit=2',
          token: servant.token);
      childIds = [for (final k in kids.rows) k['id'] as String];
    }

    Future<Map<String, dynamic>?> row(String childId) async {
      final servant = await _login('servant');
      final r = await _call(
          'GET',
          '/rest/v1/attendance_records?session_id=eq.$sessionId&child_id=eq.$childId'
              '&select=sunday_school,vespers,mass,confession,score',
          token: servant.token);
      return r.rows.isEmpty ? null : r.rows.single as Map<String, dynamic>;
    }

    Future<void> wipe() async {
      final admin = await _login('admin');
      await _call(
          'DELETE',
          '/rest/v1/attendance_records?session_id=eq.$sessionId'
              '&child_id=in.(${childIds.join(',')})',
          token: admin.token);
    }

    const upsert =
        '/rest/v1/attendance_records?on_conflict=session_id%2Cchild_id';

    dev('a partial save keeps a co-servant\'s other marks', () async {
      await findSession();
      final admin = await _login('admin');
      final servant = await _login('servant');
      await wipe();
      try {
        await _call('POST', upsert,
            token: admin.token,
            body: [
              {
                'session_id': sessionId,
                'child_id': childIds[0],
                'vespers': true
              }
            ],
            prefer: 'resolution=merge-duplicates');
        final r = await _call('POST', upsert,
            token: servant.token,
            body: [
              {'session_id': sessionId, 'child_id': childIds[0], 'mass': true}
            ],
            prefer: 'resolution=merge-duplicates');
        expect(r.ok, isTrue);
        final saved = (await row(childIds[0]))!;
        expect(saved['vespers'], isTrue);
        expect(saved['mass'], isTrue);
        expect(saved['score'], greaterThan(5));

        // A mark turned off clears only that mark.
        await _call('POST', upsert,
            token: servant.token,
            body: [
              {
                'session_id': sessionId,
                'child_id': childIds[0],
                'vespers': false
              }
            ],
            prefer: 'resolution=merge-duplicates');
        final off = (await row(childIds[0]))!;
        expect(off['vespers'], isFalse);
        expect(off['mass'], isTrue);
      } finally {
        await wipe();
      }
    });

    dev('insert-if-missing stores an absent child and never overwrites',
        () async {
      await findSession();
      final admin = await _login('admin');
      final servant = await _login('servant');
      await wipe();
      try {
        await _call('POST', upsert,
            token: admin.token,
            body: [
              {'session_id': sessionId, 'child_id': childIds[0], 'mass': true}
            ],
            prefer: 'resolution=merge-duplicates');
        final r = await _call('POST', upsert,
            token: servant.token,
            body: [
              {'session_id': sessionId, 'child_id': childIds[0]},
              {'session_id': sessionId, 'child_id': childIds[1]},
            ],
            prefer: 'resolution=ignore-duplicates');
        expect(r.ok, isTrue);
        expect((await row(childIds[0]))!['mass'], isTrue);
        final absent = (await row(childIds[1]))!;
        expect(absent['score'], 0);
        expect([absent['sunday_school'], absent['vespers'], absent['mass']],
            everyElement(isFalse));
      } finally {
        await wipe();
      }
    });

    dev('a locked Saturday refuses a servant, and only an admin can lock',
        () async {
      await findSession();
      final admin = await _login('admin');
      final servant = await _login('servant');

      final lockAsServant = await _call(
          'PATCH', '/rest/v1/attendance_sessions?id=eq.$sessionId',
          token: servant.token, body: {'is_locked': true});
      expect(lockAsServant.status, 403);

      await _call('PATCH', '/rest/v1/attendance_sessions?id=eq.$sessionId',
          token: admin.token, body: {'is_locked': true});
      try {
        final r = await _call('POST', upsert,
            token: servant.token,
            body: [
              {'session_id': sessionId, 'child_id': childIds[0], 'mass': true}
            ],
            prefer: 'resolution=merge-duplicates');
        expect(r.status, 403);
        // The admin can still write to a locked Saturday.
        final byAdmin = await _call('POST', upsert,
            token: admin.token,
            body: [
              {'session_id': sessionId, 'child_id': childIds[0], 'mass': true}
            ],
            prefer: 'resolution=merge-duplicates');
        expect(byAdmin.ok, isTrue);
      } finally {
        await _call('PATCH', '/rest/v1/attendance_sessions?id=eq.$sessionId',
            token: admin.token, body: {'is_locked': false});
        await wipe();
      }
    });

    dev('a mark cannot be written for a child of another class', () async {
      await findSession();
      final servant = await _login('servant');
      final admin = await _login('admin');
      final other = await _call('GET',
          '/rest/v1/attendance_sessions?select=class_id&id=eq.$sessionId',
          token: servant.token);
      final classId = other.rows.single['class_id'];
      final stranger = await _call(
          'GET', '/rest/v1/children?select=id&class_id=neq.$classId&limit=1',
          token: admin.token);
      final r = await _call('POST', upsert,
          token: admin.token,
          body: [
            {
              'session_id': sessionId,
              'child_id': stranger.rows.single['id'],
              'mass': true
            }
          ],
          prefer: 'resolution=merge-duplicates');
      expect(r.ok, isFalse);
    });
  });

  group('the general servant', () {
    dev('cannot add children or lock a Saturday, but can take attendance',
        () async {
      final general = await _login('general');
      final admin = await _login('admin');
      final servant = await _login('servant');

      final classes = await _call('GET', '/rest/v1/classes?select=id&limit=1',
          token: admin.token);
      final add =
          await _call('POST', '/rest/v1/children', token: general.token, body: {
        'class_id': classes.rows.single['id'],
        'full_name': 'اختبار ممنوع',
        'gender': 'boy',
      });
      expect(add.ok, isFalse);

      final session = await _call('GET',
          '/rest/v1/attendance_sessions?select=id,class_id&is_locked=eq.false&limit=1',
          token: servant.token);
      final sid = session.rows.single['id'];
      final lock = await _call(
          'PATCH', '/rest/v1/attendance_sessions?id=eq.$sid',
          token: general.token, body: {'is_locked': true});
      expect(lock.status, 403);

      final kid = await _call('GET',
          '/rest/v1/children?select=id&class_id=eq.${session.rows.single['class_id']}&limit=1',
          token: servant.token);
      final child = kid.rows.single['id'];
      final write = await _call('POST',
          '/rest/v1/attendance_records?on_conflict=session_id%2Cchild_id',
          token: general.token,
          body: [
            {'session_id': sid, 'child_id': child, 'sunday_school': true}
          ],
          prefer: 'resolution=merge-duplicates');
      try {
        expect(write.ok, isTrue);
      } finally {
        await _call('DELETE',
            '/rest/v1/attendance_records?session_id=eq.$sid&child_id=eq.$child',
            token: admin.token);
      }
    });
  });

  group('the activity log', () {
    dev('only an admin reads it, and an attendance save names the child',
        () async {
      final servant = await _login('servant');
      final admin = await _login('admin');

      final session = await _call(
          'GET',
          '/rest/v1/attendance_sessions?select=id,class_id&is_locked=eq.false'
              '&order=session_date.desc&limit=1',
          token: servant.token);
      final sid = session.rows.single['id'] as String;
      final kid = await _call(
          'GET',
          '/rest/v1/children?select=id,full_name&class_id=eq.${session.rows.single['class_id']}'
              '&is_active=eq.true&order=full_name&limit=1',
          token: servant.token);
      final childId = kid.rows.single['id'] as String;
      final childName = kid.rows.single['full_name'] as String;

      Future<void> wipe() => _call('DELETE',
          '/rest/v1/attendance_records?session_id=eq.$sid&child_id=eq.$childId',
          token: admin.token);

      await wipe();
      try {
        final save = await _call('POST',
            '/rest/v1/attendance_records?on_conflict=session_id%2Cchild_id',
            token: servant.token,
            body: [
              {
                'session_id': sid,
                'child_id': childId,
                'mass': true,
                'vespers': true,
              }
            ],
            prefer: 'resolution=merge-duplicates');
        expect(save.ok, isTrue);

        // A servant sees nothing of it.
        final asServant = await _call('GET', '/rest/v1/activity_log?select=id',
            token: servant.token);
        expect(asServant.rows, isEmpty);

        // The admin finds it by the child, the way the app asks.
        final or = Uri.encodeQueryComponent(
            '(entity_id.eq.$childId,details->>child_id.eq.$childId)');
        final found = await _call(
            'GET',
            '/rest/v1/activity_log?select=*&or=$or'
                '&order=created_at.desc,id.desc&limit=5',
            token: admin.token);
        expect(found.ok, isTrue, reason: '${found.body}');
        final entry = found.rows.first as Map<String, dynamic>;
        final details = entry['details'] as Map<String, dynamic>;
        expect(entry['entity'], 'attendance_records');
        expect(entry['actor_id'], servant.id);
        expect(details['child_id'], childId);
        expect(details['child_name'], childName);
        expect(details['mass'], isTrue);
        expect(details['vespers'], isTrue);
        expect(details['sunday_school'], isFalse);

        // ... by who did it and by the kind of record.
        final byActor = await _call(
            'GET',
            '/rest/v1/activity_log?select=id&actor_id=eq.${servant.id}'
                '&entity=eq.attendance_records&limit=1',
            token: admin.token);
        expect(byActor.rows, hasLength(1));
      } finally {
        await wipe();
      }
    });
  });

  group('the new-year promotion', () {
    Future<_Reply> promote(_Who who, String suffix, {bool dry = false}) =>
        _call('POST', '/rest/v1/rpc/promote_grades',
            token: who.token,
            body: {'p_archive_suffix': suffix, 'p_dry_run': dry});

    Future<List<Map<String, dynamic>>> classes(_Who admin) async {
      final r = await _call('GET',
          '/rest/v1/classes?select=id,name,sort_order,is_active&order=name',
          token: admin.token);
      return [for (final c in r.rows) c as Map<String, dynamic>];
    }

    dev('only an admin can promote, and a year name is required', () async {
      final servant = await _login('servant');
      final admin = await _login('admin');
      expect((await promote(servant, 'x', dry: true)).ok, isFalse);
      expect((await promote(admin, '   ', dry: true)).ok, isFalse);
      expect((await promote(admin, 'x', dry: true)).ok, isTrue);
    });

    dev('the preview changes nothing; the real run moves every class in one go and cannot be repeated',
        () async {
      final admin = await _login('admin');
      final before = await classes(admin);
      final names = {for (final c in before) c['name'] as String: c['id']};
      // The promotion expects the real class names; dev has them.
      for (final n in [
        '3 ولاد',
        '3 بنات',
        '4 ولاد',
        '5 ولاد',
        '6 ولاد',
        '6 بنات'
      ]) {
        expect(names.containsKey(n), isTrue, reason: 'dev has no class $n');
      }
      final kids = await _call('GET', '/rest/v1/children?select=id,is_active',
          token: admin.token);
      final wasActive = {
        for (final k in kids.rows)
          if (k['is_active'] == true) k['id'] as String
      };
      final suffix = 'اختبار-${DateTime.now().microsecondsSinceEpoch}';

      try {
        // The preview.
        final preview = await promote(admin, suffix, dry: true);
        expect(preview.ok, isTrue, reason: '${preview.body}');
        final plan = preview.body as Map<String, dynamic>;
        expect(plan['dryRun'], isTrue);
        expect((plan['moves'] as List).length, 6);
        expect((plan['archived'] as List).length, 2);
        expect(plan['created'], ['3 ولاد', '3 بنات']);
        expect(await classes(admin), before,
            reason: 'the preview changed something');

        // The real run.
        final run = await promote(admin, suffix);
        expect(run.ok, isTrue, reason: '${run.body}');
        final after = await classes(admin);
        final byId = {for (final c in after) c['id'] as String: c};
        expect(byId[names['5 ولاد']]!['name'], '6 ولاد');
        expect(byId[names['4 ولاد']]!['name'], '5 ولاد');
        expect(byId[names['3 ولاد']]!['name'], '4 ولاد');
        expect(byId[names['6 ولاد']]!['name'], '6 ولاد $suffix');
        expect(byId[names['6 ولاد']]!['is_active'], isFalse);
        expect(after.length, before.length + 2);
        expect(after.where((c) => ['3 ولاد', '3 بنات'].contains(c['name'])),
            hasLength(2));

        // The graduating class leaves the lists with its children.
        final graduated = await _call(
            'GET',
            '/rest/v1/children?select=id&class_id=eq.${names['6 ولاد']}'
                '&is_active=eq.true',
            token: admin.token);
        expect(graduated.rows, isEmpty);

        // A second run for the same year is refused, and changes nothing.
        final again = await promote(admin, suffix);
        expect(again.ok, isFalse);
        expect(await classes(admin), after);
      } finally {
        // Put dev back as it was: first free every name, then restore.
        final now = await classes(admin);
        final original = {for (final c in before) c['id']};
        for (final c in now) {
          if (!original.contains(c['id'])) {
            await _call('DELETE', '/rest/v1/classes?id=eq.${c['id']}',
                token: admin.token);
          } else {
            await _call('PATCH', '/rest/v1/classes?id=eq.${c['id']}',
                token: admin.token, body: {'name': 'tmp-${c['id']}'});
          }
        }
        for (final c in before) {
          await _call('PATCH', '/rest/v1/classes?id=eq.${c['id']}',
              token: admin.token,
              body: {
                'name': c['name'],
                'sort_order': c['sort_order'],
                'is_active': c['is_active'],
              });
        }
        if (wasActive.isNotEmpty) {
          await _call(
              'PATCH', '/rest/v1/children?id=in.(${wasActive.join(',')})',
              token: admin.token, body: {'is_active': true});
        }
        expect(await classes(admin), before, reason: 'dev was not put back');
      }
    });
  });

  group('telling the other servants of a class', () {
    late _Who servant;
    late _Who admin;
    late _Who general; // stands in for a second servant of the class
    late String classId;
    late String servantName;
    final madeChildren = <String>[];

    Future<List<Map<String, dynamic>>> inbox(_Who who) async {
      final r = await _call(
          'GET',
          '/rest/v1/notifications?select=kind,title,body,ref_id,child_id'
              '&created_at=gte.$started&order=created_at.desc',
          token: who.token);
      return [for (final n in r.rows) n as Map<String, dynamic>];
    }

    Future<void> clearInbox(_Who who) =>
        _call('DELETE', '/rest/v1/notifications?created_at=gte.$started',
            token: who.token);

    setUp(() async {
      if (skip != null) return;
      servant = await _login('servant');
      admin = await _login('admin');
      general = await _login('general');
      final mine = await _call('GET',
          '/rest/v1/class_servants?select=class_id&servant_id=eq.${servant.id}',
          token: admin.token);
      classId = mine.rows.single['class_id'] as String;
      final name = await _call(
          'GET', '/rest/v1/profiles?select=full_name&id=eq.${servant.id}',
          token: admin.token);
      servantName = name.rows.single['full_name'] as String;
      final a = await _call('POST', '/rest/v1/class_servants',
          token: admin.token,
          body: {'class_id': classId, 'servant_id': general.id});
      expect(a.ok, isTrue,
          reason: 'could not assign a second servant: ${a.body}');
      await clearInbox(general);
      await clearInbox(servant);
    });

    tearDown(() async {
      if (skip != null) return;
      for (final id in madeChildren) {
        await _call('DELETE', '/rest/v1/children?id=eq.$id',
            token: admin.token);
      }
      madeChildren.clear();
      await _call(
          'DELETE',
          '/rest/v1/class_servants?class_id=eq.$classId'
              '&servant_id=eq.${general.id}',
          token: admin.token);
      await clearInbox(general);
      await clearInbox(servant);
    });

    dev('attendance taken: the others hear once, the one who took it does not',
        () async {
      final s = await _call(
          'GET',
          '/rest/v1/attendance_sessions?select=id,session_date'
              '&class_id=eq.$classId&is_locked=eq.false'
              '&order=session_date.desc&limit=1',
          token: servant.token);
      final sid = s.rows.single['id'] as String;
      final kid = await _call(
          'GET',
          '/rest/v1/children?select=id&class_id=eq.$classId'
              '&is_active=eq.true&limit=2',
          token: servant.token);
      final kids = [for (final k in kid.rows) k['id'] as String];
      Future<void> save(String mark) => _call('POST',
          '/rest/v1/attendance_records?on_conflict=session_id%2Cchild_id',
          token: servant.token,
          body: [
            for (final k in kids) {'session_id': sid, 'child_id': k, mark: true}
          ],
          prefer: 'resolution=merge-duplicates');
      try {
        await save('mass');
        await save('vespers'); // a second save soon after
        final got = (await inbox(general))
            .where((n) => n['kind'] == 'attendance_taken')
            .toList();
        expect(got, hasLength(1));
        expect(got.single['body'], contains(servantName));
        expect(got.single['body'], contains(s.rows.single['session_date']));
        expect(got.single['ref_id'], classId);
        expect(
            (await inbox(servant))
                .where((n) => n['kind'] == 'attendance_taken'),
            isEmpty);
      } finally {
        await _call(
            'DELETE',
            '/rest/v1/attendance_records?session_id=eq.$sid'
                '&child_id=in.(${kids.join(',')})',
            token: admin.token);
      }
    });

    dev('a child added, edited, stopped, visited and the class changed',
        () async {
      // Added.
      final add = await _call('POST', '/rest/v1/children',
          token: servant.token,
          body: {
            'class_id': classId,
            'full_name': 'اختبار إشعار',
            'gender': 'boy',
          },
          prefer: 'return=representation');
      expect(add.ok, isTrue, reason: '${add.body}');
      final childId = add.rows.single['id'] as String;
      madeChildren.add(childId);
      var got = await inbox(general);
      expect(
          got.where((n) =>
              n['kind'] == 'child_added' &&
              n['ref_id'] == childId &&
              (n['body'] as String).contains(servantName)),
          hasLength(1));

      // Edited: told once, however many times it is saved.
      await _call('PATCH', '/rest/v1/children?id=eq.$childId',
          token: servant.token, body: {'mobile': '01099990001'});
      await _call('PATCH', '/rest/v1/children?id=eq.$childId',
          token: servant.token, body: {'mobile': '01099990002'});
      got = await inbox(general);
      expect(got.where((n) => (n['body'] as String).contains('عدّل بيانات')),
          hasLength(1));
      expect(got.firstWhere((n) => n['kind'] == 'class_activity')['ref_id'],
          classId);
      // About one child: it also names the child, so the bell opens them.
      expect(got.firstWhere((n) => n['kind'] == 'class_activity')['child_id'],
          childId);

      // Stopped.
      await _call('PATCH', '/rest/v1/children?id=eq.$childId',
          token: servant.token, body: {'is_active': false});
      got = await inbox(general);
      expect(got.where((n) => (n['body'] as String).contains('أوقف')),
          hasLength(1));

      // A visit written down.
      await _call('POST', '/rest/v1/child_visit_logs',
          token: servant.token,
          body: {
            'child_id': childId,
            'visit_type': 'phone',
            'visit_date': '2026-11-01',
            'recorded_by': servant.id,
          });
      got = await inbox(general);
      expect(
          got.where(
              (n) => (n['body'] as String).contains('سجّل افتقاد (اتصال)')),
          hasLength(1));

      // The class's own details.
      final cls = await _call(
          'GET', '/rest/v1/classes?select=patron_name&id=eq.$classId',
          token: admin.token);
      final patron = cls.rows.single['patron_name'];
      try {
        await _call('PATCH', '/rest/v1/classes?id=eq.$classId',
            token: servant.token, body: {'patron_name': 'اسم اختبار'});
        got = await inbox(general);
        expect(
            got.where(
                (n) => (n['body'] as String).contains('عدّل بيانات الفصل')),
            hasLength(1));
      } finally {
        await _call('PATCH', '/rest/v1/classes?id=eq.$classId',
            token: admin.token, body: {'patron_name': patron});
      }

      // Nothing of it went to the one who did it.
      expect(
          (await inbox(servant)).where((n) =>
              n['kind'] == 'class_activity' || n['kind'] == 'child_added'),
          isEmpty);
      final countBefore = (await inbox(general)).length;

      // An admin who does not serve the class tells nobody.
      await _call('PATCH', '/rest/v1/children?id=eq.$childId',
          token: admin.token, body: {'notes': 'ملاحظة من الأدمن'});
      expect((await inbox(general)).length, countBefore);
    });
  });

  group('a child\'s place on the map', () {
    late _Who servant;
    late _Who admin;
    late _Who general;
    late String childId;
    late dynamic before;

    setUp(() async {
      if (skip != null) return;
      servant = await _login('servant');
      admin = await _login('admin');
      general = await _login('general');
      final kid = await _call(
          'GET', '/rest/v1/children?select=id,latitude,longitude&limit=1',
          token: servant.token);
      childId = kid.rows.single['id'] as String;
      before = [kid.rows.single['latitude'], kid.rows.single['longitude']];
    });

    tearDown(() async {
      if (skip != null) return;
      await _call('PATCH', '/rest/v1/children?id=eq.$childId',
          token: admin.token,
          body: {'latitude': before[0], 'longitude': before[1]});
    });

    Future<_Reply> setPlace(_Who who, Object? lat, Object? lng) =>
        _call('PATCH', '/rest/v1/children?id=eq.$childId',
            token: who.token, body: {'latitude': lat, 'longitude': lng});

    Future<List<dynamic>> place(_Who who) async {
      final r = await _call(
          'GET', '/rest/v1/children?select=latitude,longitude&id=eq.$childId',
          token: who.token);
      return [r.rows.single['latitude'], r.rows.single['longitude']];
    }

    dev('a servant of the class saves, reads and clears it', () async {
      final saved = await setPlace(servant, 30.05611, 31.34167);
      expect(saved.ok, isTrue, reason: '${saved.body}');
      expect(await place(servant), [30.05611, 31.34167]);

      final cleared = await setPlace(servant, null, null);
      expect(cleared.ok, isTrue);
      expect(await place(servant), [null, null]);
    });

    dev('half a place, or one off the globe, is refused', () async {
      expect((await setPlace(servant, 30.0, null)).ok, isFalse);
      expect((await setPlace(servant, null, 31.0)).ok, isFalse);
      expect((await setPlace(servant, 91.0, 31.0)).ok, isFalse);
      expect((await setPlace(servant, 30.0, 181.0)).ok, isFalse);
      expect((await setPlace(servant, -90.0, -180.0)).ok, isTrue); // the edge
      // Nothing half-written got in.
      expect(await place(servant), [-90, -180]);
    });

    dev('the general servant reads but cannot change it', () async {
      await setPlace(servant, 30.0, 31.0);
      final byGeneral = await setPlace(general, 1.0, 2.0);
      // Row security hides the update: nothing changes.
      expect(await place(servant), [30, 31]);
      expect(byGeneral.status, anyOf(200, 204, 403));
    });

    dev('an admin can set it too', () async {
      expect((await setPlace(admin, 29.9, 31.2)).ok, isTrue);
      expect(await place(admin), [29.9, 31.2]);
    });
  });

  group('push registration', () {
    Future<List<dynamic>> mine(_Who who, List<String> tokens) async {
      final r = await _call('GET',
          '/rest/v1/device_tokens?select=token,user_id&token=in.(${tokens.join(',')})',
          token: who.token);
      return r.rows;
    }

    Future<void> forget(_Who who, List<String> tokens) =>
        _call('DELETE', '/rest/v1/device_tokens?token=in.(${tokens.join(',')})',
            token: who.token);

    dev('a new installation id drops the old token of the same user, only theirs',
        () async {
      final servant = await _login('servant');
      final admin = await _login('admin');
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final legacy = 'legacy-token-$stamp';
      final others = 'other-user-token-$stamp';
      final fid = 'F${stamp.toString().padLeft(21, '0').substring(0, 21)}';
      final all = [legacy, others, fid];

      Future<_Reply> register(_Who who, String token, {String? replaces}) =>
          _call('POST', '/rest/v1/rpc/register_device_token',
              token: who.token,
              body: {
                'p_token': token,
                'p_platform': 'android',
                if (replaces != null) 'p_replaces': replaces,
              });

      try {
        expect((await register(servant, legacy)).ok, isTrue);
        expect((await register(admin, others)).ok, isTrue);

        // The servant's phone moves to an installation id and names its token,
        // and also names somebody else's token by mistake or on purpose.
        expect((await register(servant, fid, replaces: legacy)).ok, isTrue);
        expect((await register(servant, fid, replaces: others)).ok, isTrue);

        expect((await mine(servant, [legacy])).map((r) => r['token']), isEmpty);
        expect((await mine(servant, [fid])).single['user_id'], servant.id);
        expect((await mine(admin, [others])).single['user_id'], admin.id);
      } finally {
        await forget(servant, all);
        await forget(admin, all);
      }
    });

    dev('registering without a token to replace still works (older app)',
        () async {
      final servant = await _login('servant');
      final token = 'plain-token-${DateTime.now().microsecondsSinceEpoch}';
      try {
        final r = await _call('POST', '/rest/v1/rpc/register_device_token',
            token: servant.token,
            body: {'p_token': token, 'p_platform': 'web'});
        expect(r.ok, isTrue, reason: '${r.body}');
        expect(await mine(servant, [token]), hasLength(1));
      } finally {
        await forget(servant, [token]);
      }
    });
  });

  group('visit history', () {
    dev('a visit entry can be deleted by whoever wrote it, not by another servant',
        () async {
      final servant = await _login('servant');
      final general = await _login('general');
      final kid = await _call('GET', '/rest/v1/children?select=id&limit=1',
          token: servant.token);
      final created = await _call('POST', '/rest/v1/child_visit_logs',
          token: servant.token,
          body: {
            'child_id': kid.rows.single['id'],
            'visit_type': 'phone',
            'visit_date': '2026-01-01',
            'notes': 'اختبار',
            'recorded_by': servant.id,
          },
          prefer: 'return=representation');
      expect(created.ok, isTrue, reason: '${created.body}');
      final id = created.rows.single['id'];

      final byOther = await _call(
          'DELETE', '/rest/v1/child_visit_logs?id=eq.$id&select=id',
          token: general.token, prefer: 'return=representation');
      expect(byOther.rows, isEmpty);

      final byOwner = await _call(
          'DELETE', '/rest/v1/child_visit_logs?id=eq.$id&select=id',
          token: servant.token, prefer: 'return=representation');
      expect(byOwner.rows, hasLength(1));
    });
  });

  group('private health notes', () {
    dev('only that class\'s servants and admins read or write them; '
        'the general servant never does', () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final general = await _login('general');

      // A child of the servant's own class (RLS already limits the servant).
      final kid = await _call('GET', '/rest/v1/children?select=id&limit=1',
          token: servant.token);
      final id = kid.rows.single['id'];
      final url = '/rest/v1/child_private_notes?child_id=eq.$id';

      try {
        final saved = await _call('POST', '/rest/v1/child_private_notes',
            token: servant.token,
            body: {'child_id': id, 'health_notes': 'حساسية (اختبار)'},
            prefer: 'return=representation');
        expect(saved.ok, isTrue, reason: '${saved.body}');

        final byServant = await _call('GET', url, token: servant.token);
        expect(byServant.rows, hasLength(1));
        final byAdmin = await _call('GET', url, token: admin.token);
        expect(byAdmin.rows, hasLength(1));

        // The general servant reads every child but not the note.
        final byGeneral = await _call('GET', url, token: general.token);
        expect(byGeneral.rows, isEmpty);
        final writeGeneral = await _call('POST', '/rest/v1/child_private_notes',
            token: general.token,
            body: {'child_id': id, 'health_notes': 'x'},
            prefer: 'resolution=merge-duplicates');
        expect(writeGeneral.ok, isFalse);

        // Not readable without signing in.
        final anon = await _call('GET', url);
        expect(anon.rows, isEmpty);
      } finally {
        await _call('DELETE', url, token: admin.token);
      }
    });
  });

  group('absence alerts', () {
    dev('only an admin reads or changes the alert levels', () async {
      final admin = await _login('admin');
      final servant = await _login('servant');

      final denied = await _call('POST', '/rest/v1/rpc/get_app_setting',
          token: servant.token, body: {'p_key': 'absence_alert_levels'});
      expect(denied.ok, isFalse);
      final deniedSet = await _call('POST', '/rest/v1/rpc/set_app_setting',
          token: servant.token,
          body: {'p_key': 'absence_alert_levels', 'p_value': '1'});
      expect(deniedSet.ok, isFalse);

      final before = await _call('POST', '/rest/v1/rpc/get_app_setting',
          token: admin.token, body: {'p_key': 'absence_alert_levels'});
      expect(before.ok, isTrue, reason: '${before.body}');
      try {
        final bad = await _call('POST', '/rest/v1/rpc/set_app_setting',
            token: admin.token,
            body: {'p_key': 'absence_alert_levels', 'p_value': '0,99'});
        expect(bad.ok, isFalse);
        final other = await _call('POST', '/rest/v1/rpc/get_app_setting',
            token: admin.token, body: {'p_key': 'backup_secret'});
        expect(other.ok, isFalse, reason: 'secrets must not be readable');
        final good = await _call('POST', '/rest/v1/rpc/set_app_setting',
            token: admin.token,
            body: {'p_key': 'absence_alert_levels', 'p_value': '2, 4'});
        expect(good.ok, isTrue, reason: '${good.body}');
        final now = await _call('POST', '/rest/v1/rpc/get_app_setting',
            token: admin.token, body: {'p_key': 'absence_alert_levels'});
        expect(now.body, '2,4');
      } finally {
        await _call('POST', '/rest/v1/rpc/set_app_setting',
            token: admin.token,
            body: {
              'p_key': 'absence_alert_levels',
              'p_value': (before.body ?? '2,3').toString(),
            });
      }
    });

    dev('checking an unknown session alerts nobody and does not fail',
        () async {
      final servant = await _login('servant');
      final r = await _call('POST', '/rest/v1/rpc/check_absence_alerts',
          token: servant.token,
          body: {'p_session_id': '00000000-0000-0000-0000-000000000000'});
      expect(r.ok, isTrue, reason: '${r.body}');
      expect(r.body, 0);
    });

    dev('the alert bookkeeping table is not readable through the API',
        () async {
      final admin = await _login('admin');
      final r = await _call('GET', '/rest/v1/absence_alerts?select=*',
          token: admin.token);
      expect(r.ok, isFalse);
    });
  });

  group('undo', () {
    dev('an edit can be reverted, but not after a later edit of the same field',
        () async {
      final servant = await _login('servant');
      final general = await _login('general');
      final kid = await _call('GET', '/rest/v1/children?select=id,notes&limit=1',
          token: servant.token);
      final id = kid.rows.single['id'];
      final original = kid.rows.single['notes'];
      final url = '/rest/v1/children?id=eq.$id';

      Future<int?> lastLogId() async {
        final h = await _call('POST', '/rest/v1/rpc/child_change_history',
            token: servant.token, body: {'p_child_id': id});
        for (final r in h.rows) {
          final changes = r['changes'];
          if (r['entity'] == 'children' &&
              changes is Map &&
              changes.containsKey('notes')) {
            return (r['id'] as num).toInt();
          }
        }
        return null;
      }

      try {
        await _call('PATCH', url, token: servant.token, body: {'notes': 'اختبار ١'});
        final first = await lastLogId();
        expect(first, isNotNull);

        // The general servant cannot revert.
        final denied = await _call('POST', '/rest/v1/rpc/revert_child_change',
            token: general.token, body: {'p_log_id': first});
        expect(denied.ok, isFalse);

        final ok = await _call('POST', '/rest/v1/rpc/revert_child_change',
            token: servant.token, body: {'p_log_id': first});
        expect(ok.ok, isTrue, reason: '${ok.body}');
        final back = await _call('GET', '$url&select=notes', token: servant.token);
        expect(back.rows.single['notes'], original);

        // A later edit of the same field blocks reverting the earlier one.
        await _call('PATCH', url, token: servant.token, body: {'notes': 'اختبار ٢'});
        final second = await lastLogId();
        await _call('PATCH', url, token: servant.token, body: {'notes': 'اختبار ٣'});
        final blocked = await _call('POST', '/rest/v1/rpc/revert_child_change',
            token: servant.token, body: {'p_log_id': second});
        expect(blocked.ok, isFalse);
        final still = await _call('GET', '$url&select=notes', token: servant.token);
        expect(still.rows.single['notes'], 'اختبار ٣');
      } finally {
        await _call('PATCH', url, token: servant.token, body: {'notes': original});
      }
    });

    dev('an import can be undone once, and the batch table is closed',
        () async {
      final admin = await _login('admin');
      final classes = await _call('GET', '/rest/v1/classes?select=id&limit=1',
          token: admin.token);
      final classId = classes.rows.single['id'];
      final name = 'اختبار تراجع ${DateTime.now().microsecondsSinceEpoch}';

      final imported = await _call('POST', '/rest/v1/rpc/import_children',
          token: admin.token,
          body: {
            'p_inserts': [
              {'class_id': classId, 'full_name': name, 'gender': 'boy'}
            ],
            'p_updates': [],
          });
      expect(imported.ok, isTrue, reason: '${imported.body}');
      final batch = (imported.body as Map)['batch_id'];
      expect(batch, isNotNull);

      final direct = await _call('GET', '/rest/v1/import_batches?select=*',
          token: admin.token);
      expect(direct.ok, isFalse, reason: 'the table must not be readable');

      try {
        final undone = await _call('POST', '/rest/v1/rpc/undo_import',
            token: admin.token, body: {'p_batch': batch});
        expect(undone.ok, isTrue, reason: '${undone.body}');
        expect((undone.body as Map)['deleted'], 1);
        final gone = await _call(
            'GET', '/rest/v1/children?select=id&full_name=eq.${Uri.encodeComponent(name)}',
            token: admin.token);
        expect(gone.rows, isEmpty);

        final twice = await _call('POST', '/rest/v1/rpc/undo_import',
            token: admin.token, body: {'p_batch': batch});
        expect(twice.ok, isFalse);
      } finally {
        await _call('DELETE',
            '/rest/v1/children?full_name=eq.${Uri.encodeComponent(name)}',
            token: admin.token);
      }
    });
  });

  group('the Excel import function', () {
    final made = <String>{};

    Future<void> removeMade() async {
      final admin = await _login('admin');
      for (final id in made) {
        await _call('DELETE', '/rest/v1/children?id=eq.$id',
            token: admin.token);
      }
      made.clear();
    }

    tearDown(removeMade);

    Map<String, dynamic> row(String name, String classId, {String? id}) => {
          if (id != null) 'id': id,
          'class_id': classId,
          'full_name': name,
          'gender': 'girl',
          'birth_date': '2015-04-02',
          'mobile': '01011112222',
        };

    Future<List<dynamic>> findByName(String name) async {
      final admin = await _login('admin');
      final r = await _call('GET',
          '/rest/v1/children?select=id,full_name&full_name=like.*${Uri.encodeComponent(name)}*',
          token: admin.token);
      for (final c in r.rows) {
        made.add(c['id'] as String);
      }
      return r.rows;
    }

    dev('adds new children and changes existing ones in one go, keeping what the sheet does not carry',
        () async {
      final admin = await _login('admin');
      final cls = await _call(
          'GET', '/rest/v1/classes?select=id&order=sort_order&limit=2',
          token: admin.token);
      final classA = cls.rows[0]['id'] as String;
      final classB = cls.rows[1]['id'] as String;

      // An existing child with visit dates and a deacon flag the sheet lacks.
      final seed = await _call('POST', '/rest/v1/children',
          token: admin.token,
          body: {
            'class_id': classA,
            'full_name': 'اختبار استيراد قديم',
            'gender': 'boy',
            'is_deacon': true,
            'last_phone_visit_date': '2026-10-01',
            'last_home_visit_notes': 'زيارة قبل الاستيراد',
          },
          prefer: 'return=representation');
      expect(seed.ok, isTrue, reason: '${seed.body}');
      final existing = seed.rows.single['id'] as String;
      made.add(existing);

      final r = await _call('POST', '/rest/v1/rpc/import_children',
          token: admin.token,
          body: {
            'p_inserts': [
              row('اختبار استيراد جديد ١', classA),
              row('اختبار استيراد جديد ٢', classB),
            ],
            'p_updates': [
              {
                ...row('اختبار استيراد معدل', classB, id: existing),
                'gender': 'boy'
              },
            ],
          });
      expect(r.ok, isTrue, reason: '${r.body}');
      expect(r.body, containsPair('inserted', 2));
      expect(r.body, containsPair('updated', 1));
      expect((r.body as Map)['batch_id'], isNotNull);
      await findByName('اختبار استيراد');
      expect(made, hasLength(3));

      final after = await _call('GET',
          '/rest/v1/children?id=eq.$existing&select=full_name,class_id,mobile,is_deacon,is_active,last_phone_visit_date,last_home_visit_notes,code',
          token: admin.token);
      final c = after.rows.single as Map<String, dynamic>;
      expect(c['full_name'], 'اختبار استيراد معدل');
      expect(c['class_id'], classB);
      expect(c['mobile'], '01011112222');
      // Not in a sheet, so not touched.
      expect(c['is_deacon'], isTrue);
      expect(c['is_active'], isTrue);
      expect(c['last_phone_visit_date'], '2026-10-01');
      expect(c['last_home_visit_notes'], 'زيارة قبل الاستيراد');
      expect(c['code'], isNotNull);
    });

    dev('one bad row undoes the whole import', () async {
      final admin = await _login('admin');
      final cls = await _call('GET', '/rest/v1/classes?select=id&limit=1',
          token: admin.token);
      final classId = cls.rows.single['id'] as String;

      final r = await _call('POST', '/rest/v1/rpc/import_children',
          token: admin.token,
          body: {
            'p_inserts': [row('اختبار تراجع يجب ألا يُحفظ', classId)],
            'p_updates': [
              row('لا يوجد', classId,
                  id: '00000000-0000-0000-0000-000000000000'),
            ],
          });
      expect(r.ok, isFalse);

      expect(await findByName('اختبار تراجع'), isEmpty);
    });

    dev('a servant cannot import into another class (nothing is saved)',
        () async {
      final servant = await _login('servant');
      final admin = await _login('admin');
      final mine = await _call(
          'GET', '/rest/v1/children?select=class_id&limit=1',
          token: servant.token);
      final myClass = mine.rows.single['class_id'];
      final other = await _call(
          'GET', '/rest/v1/classes?select=id&id=neq.$myClass&limit=1',
          token: admin.token);

      final r = await _call('POST', '/rest/v1/rpc/import_children',
          token: servant.token,
          body: {
            'p_inserts': [
              row('اختبار فصل غريب', myClass as String),
              row('اختبار فصل غريب ٢', other.rows.single['id'] as String),
            ],
            'p_updates': <Object>[],
          });
      expect(r.ok, isFalse);
      expect(await findByName('اختبار فصل غريب'), isEmpty);
    });

    dev('signed-out callers cannot run it', () async {
      final r = await _call('POST', '/rest/v1/rpc/import_children',
          body: {'p_inserts': <Object>[], 'p_updates': <Object>[]});
      expect(r.ok, isFalse);
    });
  });
  // ── 1.0.48: look-alikes, announcements, templates, class health, materials ──

  group('look-alike children', () {
    dev('a servant learns of a look-alike in another class, and only its '
        'name, class and why', () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final mine = await _call('GET',
          '/rest/v1/class_servants?select=class_id&servant_id=eq.${servant.id}',
          token: admin.token);
      final myClass = mine.rows.first['class_id'];
      final classes = await _call(
          'GET', '/rest/v1/classes?select=id&is_active=eq.true&id=neq.$myClass',
          token: admin.token);
      final other = classes.rows.first['id'];

      final add = await _call('POST', '/rest/v1/children',
          token: admin.token,
          body: {
            'class_id': other,
            'full_name': 'زززشبيه عادل فؤاد',
            'gender': 'boy',
            'mother_mobile': '01012340987',
          },
          prefer: 'return=representation');
      expect(add.ok, isTrue, reason: '${add.body}');
      final id = add.rows.single['id'];
      try {
        final r = await _call('POST', '/rest/v1/rpc/similar_children',
            token: servant.token,
            body: {
              'p_candidates': [
                // Two spaces: still the same child.
                {'key': 'father', 'name': 'زززشبيه  عادل', 'mobiles': []},
                {
                  'key': 'phone',
                  'name': 'زززشبيه مختلف',
                  'mobiles': ['+20 101 234 0987'],
                },
                // A brother: the mother's number, another first name.
                {
                  'key': 'brother',
                  'name': 'زززأخوه عادل فؤاد',
                  'mobiles': ['01012340987'],
                },
                {'key': 'self', 'name': 'زززشبيه عادل فؤاد', 'exclude_id': id},
              ],
            });
        expect(r.ok, isTrue, reason: '${r.body}');
        final byKey = {
          for (final row in r.rows) (row as Map)['key']: row,
        };
        expect(byKey['father']?['child_id'], id);
        expect(byKey['father']?['reason'], 'same_first_and_father');
        expect(byKey['phone']?['reason'], 'same_first_and_phone');
        expect(byKey.containsKey('brother'), isFalse);
        expect(byKey.containsKey('self'), isFalse);
        expect(byKey['father']!.keys.toSet(), {
          'key',
          'child_id',
          'full_name',
          'class_id',
          'class_name',
          'is_active',
          'reason',
        });

        final anon = await _call('POST', '/rest/v1/rpc/similar_children',
            body: {
              'p_candidates': [
                {'key': 'x', 'name': 'زززشبيه عادل'},
              ],
            });
        expect(anon.ok && anon.rows.isNotEmpty, isFalse);
      } finally {
        await _call('DELETE', '/rest/v1/children?id=eq.$id',
            token: admin.token);
      }
    });
  });

  group('announcements', () {
    dev('only the admin sends; the audience alone gets it; reads are counted; '
        'deleting it clears the bells', () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final general = await _login('general');

      final denied = await _call('POST', '/rest/v1/rpc/send_announcement',
          token: servant.token,
          body: {
            'p_title': 'x',
            'p_body': 'x',
            'p_audience': 'all',
            'p_class_ids': <String>[],
          });
      expect(denied.ok, isFalse);

      final sent = await _call('POST', '/rest/v1/rpc/send_announcement',
          token: admin.token,
          body: {
            'p_title': 'اختبار إعلان',
            'p_body': 'نص إعلان للاختبار',
            'p_audience': 'servants',
            'p_class_ids': <String>[],
          });
      expect(sent.ok, isTrue, reason: '${sent.body}');
      final id = (sent.body as Map)['id'] as String;
      expect((sent.body as Map)['recipients'], greaterThanOrEqualTo(1));
      try {
        Future<List<dynamic>> bell(_Who who) async => (await _call(
                'GET',
                '/rest/v1/notifications?select=id,read_at'
                    '&kind=eq.announcement&ref_id=eq.$id',
                token: who.token))
            .rows;

        final mine = await bell(servant);
        expect(mine, hasLength(1));
        expect(await bell(general), isEmpty, reason: 'servants only');
        expect(await bell(admin), isEmpty, reason: 'not the sender');

        Future<Map> summary() async {
          final r = await _call('POST', '/rest/v1/rpc/announcements_summary',
              token: admin.token, body: <String, dynamic>{});
          return r.rows.firstWhere((a) => (a as Map)['id'] == id) as Map;
        }

        expect((await summary())['read_count'], 0);
        await _call('PATCH',
            '/rest/v1/notifications?id=eq.${(mine.single as Map)['id']}',
            token: servant.token,
            body: {'read_at': DateTime.now().toUtc().toIso8601String()});
        expect((await summary())['read_count'], 1);
        final reads = await _call('POST', '/rest/v1/rpc/announcement_reads',
            token: admin.token, body: {'p_id': id});
        final row = reads.rows
            .firstWhere((r) => (r as Map)['user_id'] == servant.id) as Map;
        expect(row['read_at'], isNotNull);

        // Not for a servant to read.
        final list = await _call('POST', '/rest/v1/rpc/announcements_summary',
            token: servant.token, body: <String, dynamic>{});
        expect(list.rows, isEmpty);
        final table = await _call('GET', '/rest/v1/announcements?select=id',
            token: servant.token);
        expect(table.rows, isEmpty);
        final who = await _call('POST', '/rest/v1/rpc/announcement_reads',
            token: servant.token, body: {'p_id': id});
        expect(who.rows, isEmpty);

        // A servant cannot delete it; the admin's delete clears every bell.
        await _call('DELETE', '/rest/v1/announcements?id=eq.$id',
            token: servant.token);
        expect(await bell(servant), hasLength(1));
        final del = await _call('DELETE', '/rest/v1/announcements?id=eq.$id',
            token: admin.token);
        expect(del.ok, isTrue, reason: '${del.body}');
        expect(await bell(servant), isEmpty);
      } finally {
        await _call('DELETE', '/rest/v1/announcements?id=eq.$id',
            token: admin.token);
      }
    });

    dev('chosen classes: their servants get it; no class is refused',
        () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final mine = await _call('GET',
          '/rest/v1/class_servants?select=class_id&servant_id=eq.${servant.id}',
          token: admin.token);
      final sent = await _call('POST', '/rest/v1/rpc/send_announcement',
          token: admin.token,
          body: {
            'p_title': 'اختبار فصل',
            'p_body': 'لفصل واحد',
            'p_audience': 'classes',
            'p_class_ids': [mine.rows.first['class_id']],
          });
      expect(sent.ok, isTrue, reason: '${sent.body}');
      final id = (sent.body as Map)['id'];
      try {
        final got = await _call(
            'GET',
            '/rest/v1/notifications?select=id&kind=eq.announcement'
                '&ref_id=eq.$id',
            token: servant.token);
        expect(got.rows, hasLength(1));
        final none = await _call('POST', '/rest/v1/rpc/send_announcement',
            token: admin.token,
            body: {
              'p_title': 'x',
              'p_body': 'x',
              'p_audience': 'classes',
              'p_class_ids': <String>[],
            });
        expect(none.ok, isFalse, reason: 'classes need at least one class');

        // A class nobody serves: refused, and nothing is kept.
        final served = await _call(
            'GET', '/rest/v1/class_servants?select=class_id',
            token: admin.token);
        final servedIds = {for (final r in served.rows) (r as Map)['class_id']};
        final all = await _call(
            'GET', '/rest/v1/classes?select=id&is_active=eq.true',
            token: admin.token);
        final empty = all.rows
            .map((c) => (c as Map)['id'])
            .where((id) => !servedIds.contains(id))
            .toList();
        if (empty.isNotEmpty) {
          final before = await _call('GET', '/rest/v1/announcements?select=id',
              token: admin.token);
          final nobody = await _call('POST', '/rest/v1/rpc/send_announcement',
              token: admin.token,
              body: {
                'p_title': 'x',
                'p_body': 'x',
                'p_audience': 'classes',
                'p_class_ids': [empty.first],
              });
          expect(nobody.ok, isFalse, reason: 'nobody would get it');
          final after = await _call('GET', '/rest/v1/announcements?select=id',
              token: admin.token);
          expect(after.rows.length, before.rows.length);
        }
      } finally {
        await _call('DELETE', '/rest/v1/announcements?id=eq.$id',
            token: admin.token);
      }
    });
  });

  group('message templates', () {
    dev('everyone reads them; only the admin writes', () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final add = await _call('POST', '/rest/v1/message_templates',
          token: admin.token,
          body: {'title': 'اختبار قالب', 'body': 'سلام {الطفل}'},
          prefer: 'return=representation');
      expect(add.ok, isTrue, reason: '${add.body}');
      final id = add.rows.single['id'];
      try {
        final read = await _call(
            'GET', '/rest/v1/message_templates?select=id&id=eq.$id',
            token: servant.token);
        expect(read.rows, hasLength(1));
        final write = await _call('POST', '/rest/v1/message_templates',
            token: servant.token, body: {'title': 'x', 'body': 'x'});
        expect(write.ok, isFalse);
        await _call('PATCH', '/rest/v1/message_templates?id=eq.$id',
            token: servant.token, body: {'body': 'تغيير'});
        final still = await _call(
            'GET', '/rest/v1/message_templates?select=body&id=eq.$id',
            token: admin.token);
        expect(still.rows.single['body'], 'سلام {الطفل}');
        final anon =
            await _call('GET', '/rest/v1/message_templates?select=id');
        expect(anon.rows, isEmpty);
      } finally {
        await _call('DELETE', '/rest/v1/message_templates?id=eq.$id',
            token: admin.token);
      }
    });
  });

  group('class health', () {
    dev('the admin and the general servant read every active class; a '
        'servant only their own',
        () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final general = await _login('general');
      final year = await _call('GET',
          '/rest/v1/attendance_years?select=id&is_current=eq.true&limit=1',
          token: admin.token);
      final yearId = year.rows.single['id'];

      final r = await _call('POST', '/rest/v1/rpc/class_health',
          token: admin.token, body: {'p_year': yearId});
      expect(r.ok, isTrue, reason: '${r.body}');
      final active = await _call(
          'GET', '/rest/v1/classes?select=id&is_active=eq.true',
          token: admin.token);
      expect(r.rows, hasLength(active.rows.length));
      for (final row in r.rows) {
        final m = row as Map;
        expect(m['taken'] as int, lessThanOrEqualTo(m['held'] as int));
        expect(m['taken_late'] as int, lessThanOrEqualTo(m['taken'] as int));
        expect(m['absent_followed'] as int,
            lessThanOrEqualTo(m['absent_2plus'] as int));
        expect(m['prep_accepted'] as int,
            lessThanOrEqualTo(m['prep_submitted'] as int));
      }

      final mine = await _call('GET',
          '/rest/v1/class_servants?select=class_id&servant_id=eq.${servant.id}',
          token: admin.token);
      final myClasses = {for (final m in mine.rows) (m as Map)['class_id']};
      final own = await _call('POST', '/rest/v1/rpc/class_health',
          token: servant.token, body: {'p_year': yearId});
      expect(own.ok, isTrue, reason: '${own.body}');
      expect(own.rows, isNotEmpty);
      expect({for (final r in own.rows) (r as Map)['class_id']},
          everyElement(isIn(myClasses)));

      final byGeneral = await _call('POST', '/rest/v1/rpc/class_health',
          token: general.token, body: {'p_year': yearId});
      expect(byGeneral.rows, hasLength(active.rows.length));
      final anon = await _call('POST', '/rest/v1/rpc/class_health',
          body: {'p_year': yearId});
      expect(anon.ok, isFalse);
    });
  });

  group('lesson materials', () {
    dev('every servant reads and adds them, named as the author; a servant '
        'removes only their own; files the same', () async {
      final admin = await _login('admin');
      final servant = await _login('servant');

      final link = await _call('POST', '/rest/v1/lesson_materials',
          token: admin.token,
          body: {
            'coptic_month': 1,
            'week': 1,
            'grade': 5,
            'kind': 'link',
            'title': 'اختبار رابط',
            'url': 'https://example.com/lesson',
          },
          prefer: 'return=representation');
      expect(link.ok, isTrue, reason: '${link.body}');
      final id = link.rows.single['id'];
      String? mineId;
      const path = 'test-m1-w1/dev-test.pdf';
      const servantPath = 'test-m1-w1/by-servant.pdf';
      try {
        final read = await _call(
            'GET', '/rest/v1/lesson_materials?select=id&id=eq.$id',
            token: servant.token);
        expect(read.rows, hasLength(1));

        // A servant adds one: it is theirs, whatever they claim.
        final mine = await _call('POST', '/rest/v1/lesson_materials',
            token: servant.token,
            body: {
              'coptic_month': 1,
              'week': 1,
              'kind': 'link',
              'title': 'فيديو من خادم',
              'url': 'https://example.com/video',
              'created_by': admin.id,
            },
            prefer: 'return=representation');
        expect(mine.ok, isTrue, reason: '${mine.body}');
        mineId = mine.rows.single['id'] as String;
        expect(mine.rows.single['created_by'], servant.id);
        expect(mine.rows.single['author_name'], isNotNull);

        // Not the admin's; and no editing.
        await _call('DELETE', '/rest/v1/lesson_materials?id=eq.$id',
            token: servant.token);
        expect(
            (await _call('GET', '/rest/v1/lesson_materials?select=id&id=eq.$id',
                    token: admin.token))
                .rows,
            hasLength(1));
        await _call('PATCH', '/rest/v1/lesson_materials?id=eq.$mineId',
            token: servant.token, body: {'title': 'تغيير'});
        final still = await _call('GET',
            '/rest/v1/lesson_materials?select=title&id=eq.$mineId',
            token: admin.token);
        expect(still.rows.single['title'], 'فيديو من خادم');

        final badUrl = await _call('POST', '/rest/v1/lesson_materials',
            token: servant.token,
            body: {
              'coptic_month': 1,
              'week': 1,
              'kind': 'link',
              'title': 'x',
              'url': 'javascript:alert(1)',
            });
        expect(badUrl.ok, isFalse);

        // Their own goes.
        final gone = await _call(
            'DELETE', '/rest/v1/lesson_materials?id=eq.$mineId',
            token: servant.token, prefer: 'return=representation');
        expect(gone.rows, hasLength(1));
        mineId = null;

        // Files: both upload; each reads; a servant cannot delete the admin's.
        final up = await _upload('lesson-materials', path, admin.token);
        expect(up.ok, isTrue, reason: '${up.body}');
        final servantUp =
            await _upload('lesson-materials', servantPath, servant.token);
        expect(servantUp.ok, isTrue, reason: '${servantUp.body}');
        expect((await _download('lesson-materials', path, servant.token)).ok,
            isTrue);
        await _call('DELETE', '/storage/v1/object/lesson-materials',
            token: servant.token,
            body: {
              'prefixes': [path],
            });
        expect((await _download('lesson-materials', path, admin.token)).ok,
            isTrue);
      } finally {
        await _call('DELETE', '/rest/v1/lesson_materials?id=eq.$id',
            token: admin.token);
        if (mineId != null) {
          await _call('DELETE', '/rest/v1/lesson_materials?id=eq.$mineId',
              token: admin.token);
        }
        await _call('DELETE', '/storage/v1/object/lesson-materials',
            token: admin.token,
            body: {
              'prefixes': [path, servantPath],
            });
      }
    });
  });

  group('shared preps', () {
    dev('a servant cannot send a prep already accepted or shared; only an '
        'accepted prep is shared, by the admin; then others read it and its '
        'files, and not after it is unshared', () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final general = await _login('general');

      final mine = await _call('GET',
          '/rest/v1/class_servants?select=class_id&servant_id=eq.${servant.id}',
          token: admin.token);
      final classId = mine.rows.first['class_id'];
      final sessions = await _call(
          'GET',
          '/rest/v1/attendance_sessions?select=id&class_id=eq.$classId'
              '&order=session_date.desc&limit=40',
          token: admin.token);
      final prior = await _call(
          'GET',
          '/rest/v1/servant_lesson_preps?select=session_id'
              '&servant_id=eq.${servant.id}',
          token: admin.token);
      final used = {for (final p in prior.rows) (p as Map)['session_id']};
      final sessionId = sessions.rows
          .map((s) => (s as Map)['id'])
          .firstWhere((s) => !used.contains(s));

      for (final cheat in <Map<String, dynamic>>[
        {'status': 'accepted'},
        {'shared_at': DateTime.now().toUtc().toIso8601String()},
      ]) {
        final r = await _call('POST', '/rest/v1/servant_lesson_preps',
            token: servant.token,
            body: {
              'servant_id': servant.id,
              'session_id': sessionId,
              ...cheat,
            });
        expect(r.ok, isFalse, reason: 'insert with $cheat');
      }

      final made = await _call('POST', '/rest/v1/servant_lesson_preps',
          token: servant.token,
          body: {'servant_id': servant.id, 'session_id': sessionId},
          prefer: 'return=representation');
      expect(made.ok, isTrue, reason: '${made.body}');
      final prepId = made.rows.single['id'] as String;
      final path = '$prepId/dev-test.pdf';
      final args = <String, dynamic>{'p_month': 1, 'p_week': 1, 'p_grade': 5};
      Future<List<dynamic>> examples(_Who who) async => (await _call(
              'POST', '/rest/v1/rpc/shared_preps',
              token: who.token, body: args))
          .rows
          .where((p) => (p as Map)['prep_id'] == prepId)
          .toList();
      try {
        final up = await _upload('servant-submissions', path, servant.token);
        expect(up.ok, isTrue, reason: '${up.body}');
        await _call('POST', '/rest/v1/servant_lesson_prep_photos',
            token: servant.token,
            body: {'prep_id': prepId, 'storage_path': path});

        // Not accepted yet: cannot be shared, and stays private.
        final early = await _call('POST', '/rest/v1/rpc/share_prep',
            token: admin.token, body: {'p_prep': prepId, ...args});
        expect(early.ok, isFalse);
        expect(
            (await _download('servant-submissions', path, general.token)).ok,
            isFalse);

        await _call('PATCH', '/rest/v1/servant_lesson_preps?id=eq.$prepId',
            token: admin.token, body: {'status': 'accepted'});
        final bySelf = await _call('POST', '/rest/v1/rpc/share_prep',
            token: servant.token, body: {'p_prep': prepId, ...args});
        expect(bySelf.ok, isFalse);
        final shared = await _call('POST', '/rest/v1/rpc/share_prep',
            token: admin.token, body: {'p_prep': prepId, ...args});
        expect(shared.ok, isTrue, reason: '${shared.body}');

        final seen = await examples(general);
        expect(seen, hasLength(1));
        expect((seen.single as Map)['storage_paths'], [path]);
        expect(
            (await _download('servant-submissions', path, general.token)).ok,
            isTrue);

        await _call('POST', '/rest/v1/rpc/unshare_prep',
            token: admin.token, body: {'p_prep': prepId});
        expect(await examples(general), isEmpty);
        expect(
            (await _download('servant-submissions', path, general.token)).ok,
            isFalse);
      } finally {
        await _call('DELETE', '/storage/v1/object/servant-submissions',
            token: admin.token,
            body: {
              'prefixes': [path],
            });
        await _call('DELETE', '/rest/v1/servant_lesson_preps?id=eq.$prepId',
            token: admin.token);
        for (final who in [admin, servant]) {
          await _call(
              'DELETE',
              '/rest/v1/notifications?kind=in.(prep_submitted,prep_reviewed)'
                  '&created_at=gte.$started',
              token: who.token);
        }
      }
    });
  });

  // The queries behind the servants' activity counts and the admin's
  // optimistic attendance chips (ServantActivityRepository).
  group('servant activity counts', () {
    Future<Map<String, dynamic>> currentYear(_Who who) async {
      final r = await _call(
          'GET',
          '/rest/v1/attendance_years?select=id,start_date,end_date'
              '&is_current=eq.true&limit=1',
          token: who.token);
      return (r.rows.single as Map).cast<String, dynamic>();
    }

    dev('an admin\'s mark comes back as the saved row', () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final year = await currentYear(admin);
      // A day of the year with no confession mark yet, so nothing that was
      // already there is touched.
      final taken = await _call(
          'GET',
          '/rest/v1/servant_attendances?select=date'
              '&servant_id=eq.${servant.id}&activity_type=eq.confession',
          token: admin.token);
      final used = {for (final x in taken.rows) x['date']};
      var day = DateTime.parse(year['start_date'] as String);
      String iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      while (used.contains(iso(day))) {
        day = day.add(const Duration(days: 1));
      }
      final date = iso(day);

      final r = await _call('POST', '/rest/v1/servant_attendances',
          token: admin.token,
          prefer: 'return=representation',
          body: {
            'servant_id': servant.id,
            'activity_type': 'confession',
            'date': date,
            'recorded_by': admin.id,
          });
      final id = r.rows.isEmpty ? null : (r.rows.single as Map)['id'];
      try {
        expect(r.status, 201, reason: '${r.body}');
        final row = (r.rows.single as Map).cast<String, dynamic>();
        expect(row['id'], isNotEmpty);
        expect(row['servant_id'], servant.id);
        expect(row['date'], date);
      } finally {
        if (id != null) {
          await _call('DELETE', '/rest/v1/servant_attendances?id=eq.$id',
              token: admin.token);
        }
      }
    });

    dev('a mark from last year is not counted in this year', () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final year = await currentYear(admin);
      final start = year['start_date'] as String;
      final end = year['end_date'] as String;
      // The day before the year starts: last year.
      final before = DateTime.parse(start).subtract(const Duration(days: 1));
      final old = '${before.year.toString().padLeft(4, '0')}-'
          '${before.month.toString().padLeft(2, '0')}-'
          '${before.day.toString().padLeft(2, '0')}';
      final made = await _call('POST', '/rest/v1/servant_attendances',
          token: admin.token,
          prefer: 'return=representation',
          body: {
            'servant_id': servant.id,
            'activity_type': 'mass',
            'date': old,
            'recorded_by': admin.id,
          });
      expect(made.ok, isTrue, reason: '${made.body}');
      final id = (made.rows.single as Map)['id'];
      try {
        // The servant reads their own marks, as on «نشاطي».
        final all = await _call(
            'GET',
            '/rest/v1/servant_attendances?select=activity_type,date'
                '&servant_id=eq.${servant.id}',
            token: servant.token);
        final thisYear = await _call(
            'GET',
            '/rest/v1/servant_attendances?select=activity_type,date'
                '&servant_id=eq.${servant.id}'
                '&date=gte.$start&date=lte.$end',
            token: servant.token);
        expect(all.rows.map((x) => x['date']), contains(old));
        expect(thisYear.rows.map((x) => x['date']), isNot(contains(old)));
      } finally {
        await _call('DELETE', '/rest/v1/servant_attendances?id=eq.$id',
            token: admin.token);
      }
    });

    dev('preps can be narrowed to the year by their Saturday', () async {
      final admin = await _login('admin');
      final year = await currentYear(admin);
      final start = year['start_date'] as String;
      final end = year['end_date'] as String;
      final r = await _call(
          'GET',
          '/rest/v1/servant_lesson_preps?select=servant_id,status,'
              'attendance_sessions!inner(session_date)'
              '&attendance_sessions.session_date=gte.$start'
              '&attendance_sessions.session_date=lte.$end',
          token: admin.token);
      expect(r.ok, isTrue, reason: '${r.body}');
      for (final row in r.rows) {
        final d = (row['attendance_sessions'] as Map)['session_date'] as String;
        expect(d.compareTo(start) >= 0 && d.compareTo(end) <= 0, isTrue);
      }
    });
  });

  // A Saturday with no lesson (إجازة / نشاط ترفيهي): its kind, and that the
  // runs behind ملتزمين and the absence alerts skip it even when attendance
  // was saved that day (14 Nov 2026: one class saved with nobody ticked).
  group('no-lesson Saturdays', () {
    dev('a break is a holiday or an activity, nothing else', () async {
      final admin = await _login('admin');
      final r = await _call('POST', '/rest/v1/lesson_breaks',
          token: admin.token,
          body: {'break_date': '2031-01-04', 'kind': 'party'});
      expect(r.ok, isFalse);
      expect(r.code, '23514', reason: '${r.body}'); // check constraint
    });

    dev('a marked Saturday is flagged in every class, refused, not counted',
        () async {
      final admin = await _login('admin');
      final year = (await _call(
              'GET',
              '/rest/v1/attendance_years?select=id&is_current=eq.true',
              token: admin.token))
          .rows
          .single['id'];
      final today = DateTime.now().toIso8601String().substring(0, 10);
      // A past Saturday of this year that is not a break yet.
      final breaks = {
        for (final b in (await _call(
                'GET', '/rest/v1/lesson_breaks?select=break_date',
                token: admin.token))
            .rows)
          b['break_date'],
      };
      final sessions = (await _call(
              'GET',
              '/rest/v1/attendance_sessions?select=id,session_date,is_break'
                  '&year_id=eq.$year&session_date=lte.$today'
                  '&order=session_date.desc',
              token: admin.token))
          .rows;
      final day = sessions
          .map((s) => s['session_date'] as String)
          .firstWhere((d) => !breaks.contains(d));
      final thatDay = [
        for (final s in sessions)
          if (s['session_date'] == day) s['id'] as String,
      ];
      expect(thatDay, isNotEmpty);

      Future<int> held() async => ((await _call(
                  'GET',
                  '/rest/v1/v_child_year_scores?select=sessions_total'
                      '&year_id=eq.$year&limit=1',
                  token: admin.token))
              .rows
              .single['sessions_total'] as num)
          .toInt();
      final heldBefore = await held();

      final made = await _call('POST', '/rest/v1/lesson_breaks',
          token: admin.token,
          body: {'break_date': day, 'kind': 'holiday', 'shift': false});
      expect(made.ok, isTrue, reason: '${made.body}');
      try {
        final flagged = await _call(
            'GET',
            '/rest/v1/attendance_sessions?select=is_break'
                '&session_date=eq.$day',
            token: admin.token);
        expect(flagged.rows.every((r) => r['is_break'] == true), isTrue);

        // Nothing new can be saved on it.
        final child = (await _call('GET', '/rest/v1/children?select=id,class_id'
                '&is_active=eq.true&limit=1',
                token: admin.token))
            .rows
            .single;
        final session = (await _call(
                'GET',
                '/rest/v1/attendance_sessions?select=id'
                    '&session_date=eq.$day&class_id=eq.${child['class_id']}',
                token: admin.token))
            .rows
            .single['id'];
        final saved = await _call('POST', '/rest/v1/attendance_records',
            token: admin.token,
            prefer: 'resolution=merge-duplicates',
            body: {
              'session_id': session,
              'child_id': child['id'],
              'sunday_school': true,
              'vespers': false,
              'mass': false,
              'confession': false,
            });
        expect(saved.ok, isFalse, reason: 'saved on a no-lesson day');

        // One Saturday fewer held, for every percentage.
        expect(await held(), heldBefore - 1);
      } finally {
        await _call('DELETE', '/rest/v1/lesson_breaks?break_date=eq.$day',
            token: admin.token);
        await _call(
            'DELETE',
            '/rest/v1/notifications?kind=eq.lesson_changed'
                '&created_at=gte.$started',
            token: admin.token);
      }
      final cleared = await _call(
          'GET',
          '/rest/v1/attendance_sessions?select=is_break&session_date=eq.$day',
          token: admin.token);
      expect(cleared.rows.every((r) => r['is_break'] == false), isTrue);
      expect(await held(), heldBefore);
    });

    dev('the runs skip a Saturday marked as no lesson', () async {
      final admin = await _login('admin');
      final year = (await _call(
              'GET',
              '/rest/v1/attendance_years?select=id&is_current=eq.true',
              token: admin.token))
          .rows
          .single['id'];
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final scores = (await _call(
              'GET',
              '/rest/v1/v_session_scores?select=class_id,child_id,'
                  'session_date,score&year_id=eq.$year'
                  '&session_date=lte.$today',
              token: admin.token))
          .rows;
      final breaks = {
        for (final b in (await _call(
                'GET', '/rest/v1/lesson_breaks?select=break_date',
                token: admin.token))
            .rows)
          b['break_date'],
      };

      // A class with two or more recorded Saturdays; its latest is marked.
      final byClass = <String, Set<String>>{};
      for (final s in scores) {
        if (breaks.contains(s['session_date'])) continue;
        (byClass[s['class_id'] as String] ??= {})
            .add(s['session_date'] as String);
      }
      final entry = byClass.entries.firstWhere((e) => e.value.length >= 2);
      final classId = entry.key;
      final marked = (entry.value.toList()..sort()).last;

      // The run as the view should count it, skipping [skip].
      Map<String, int> expected(String? skip) {
        final days = (byClass[classId]!.where((d) => d != skip).toList()
              ..sort())
            .reversed
            .toList();
        final present = <String, Set<String>>{};
        for (final s in scores) {
          if (s['class_id'] != classId || ((s['score'] as num?) ?? 0) <= 0) {
            continue;
          }
          (present[s['child_id'] as String] ??= {})
              .add(s['session_date'] as String);
        }
        final out = <String, int>{};
        for (final s in scores) {
          if (s['class_id'] != classId) continue;
          final id = s['child_id'] as String;
          var n = 0;
          for (final d in days) {
            if (!(present[id]?.contains(d) ?? false)) break;
            n++;
          }
          out[id] = n;
        }
        return out;
      }

      Future<Map<String, int>> view() async => {
            for (final r in (await _call(
                    'GET',
                    '/rest/v1/v_child_attendance_streak?select=child_id,'
                        'present_streak&class_id=eq.$classId&year_id=eq.$year',
                    token: admin.token))
                .rows)
              r['child_id'] as String: r['present_streak'] as int,
          };

      final before = await view();
      for (final e in expected(null).entries) {
        expect(before[e.key], e.value, reason: 'before, ${e.key}');
      }

      final made = await _call('POST', '/rest/v1/lesson_breaks',
          token: admin.token,
          body: {'break_date': marked, 'kind': 'activity', 'shift': false});
      expect(made.ok, isTrue, reason: '${made.body}');
      try {
        final after = await view();
        for (final e in expected(marked).entries) {
          expect(after[e.key], e.value, reason: 'after, ${e.key}');
        }
      } finally {
        await _call('DELETE', '/rest/v1/lesson_breaks?break_date=eq.$marked',
            token: admin.token);
        await _call(
            'DELETE',
            '/rest/v1/notifications?kind=eq.lesson_changed'
                '&created_at=gte.$started',
            token: admin.token);
      }
    });
  });

  // A servant fixes a prep after a comment and sends it back; the admin's
  // per-servant totals are added up in the database.
  group('lesson prep: resend and totals', () {
    dev('only my own commented prep, with a file, goes back for review',
        () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final general = await _login('general');

      final mine = await _call('GET',
          '/rest/v1/class_servants?select=class_id&servant_id=eq.${servant.id}',
          token: admin.token);
      final classId = mine.rows.first['class_id'];
      final sessions = await _call(
          'GET',
          '/rest/v1/attendance_sessions?select=id&class_id=eq.$classId'
              '&is_break=eq.false&order=session_date.desc&limit=40',
          token: admin.token);
      final prior = await _call(
          'GET',
          '/rest/v1/servant_lesson_preps?select=session_id'
              '&servant_id=eq.${servant.id}',
          token: admin.token);
      final used = {for (final p in prior.rows) (p as Map)['session_id']};
      final sessionId = sessions.rows
          .map((s) => (s as Map)['id'])
          .firstWhere((s) => !used.contains(s));

      final made = await _call('POST', '/rest/v1/servant_lesson_preps',
          token: servant.token,
          body: {'servant_id': servant.id, 'session_id': sessionId},
          prefer: 'return=representation');
      expect(made.ok, isTrue, reason: '${made.body}');
      final prepId = made.rows.single['id'] as String;

      Future<_Reply> resend(_Who who) => _call(
          'POST', '/rest/v1/rpc/resubmit_prep',
          token: who.token, body: {'p_prep_id': prepId});

      try {
        // Still waiting: nothing to send back.
        expect((await resend(servant)).ok, isFalse);

        final reviewed = await _call(
            'PATCH', '/rest/v1/servant_lesson_preps?id=eq.$prepId',
            token: admin.token,
            body: {'status': 'commented', 'admin_comment': 'زوّد صورة'});
        expect(reviewed.ok, isTrue, reason: '${reviewed.body}');

        // Commented but no file left: refused.
        expect((await resend(servant)).ok, isFalse);

        final file = await _call('POST', '/rest/v1/servant_lesson_prep_photos',
            token: servant.token,
            body: {'prep_id': prepId, 'storage_path': '$prepId/dev-test.jpg'});
        expect(file.ok, isTrue, reason: '${file.body}');

        // Somebody else's prep: refused.
        final other = await resend(general);
        expect(other.ok, isFalse);
        expect(other.code, '42501');

        final r = await resend(servant);
        expect(r.ok, isTrue, reason: '${r.body}');

        final now = await _call(
            'GET',
            '/rest/v1/servant_lesson_preps?select=status,admin_comment,reviewed_at'
                '&id=eq.$prepId',
            token: admin.token);
        expect(now.rows.single['status'], 'pending');
        expect(now.rows.single['admin_comment'], 'زوّد صورة'); // kept
        expect(now.rows.single['reviewed_at'], isNull);

        final told = await _call(
            'GET',
            '/rest/v1/notifications?select=id&kind=eq.prep_submitted'
                '&ref_id=eq.$prepId&user_id=eq.${admin.id}',
            token: admin.token);
        expect(told.rows, isNotEmpty);
      } finally {
        await _call('DELETE', '/rest/v1/servant_lesson_preps?id=eq.$prepId',
            token: admin.token);
        for (final who in [admin, servant]) {
          await _call(
              'DELETE',
              '/rest/v1/notifications?kind=in.(prep_submitted,prep_reviewed)'
                  '&created_at=gte.$started',
              token: who.token);
        }
      }
    });

    dev('the totals match the rows, and only an admin reads them', () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final year = (await _call(
              'GET',
              '/rest/v1/attendance_years?select=start_date,end_date'
                  '&is_current=eq.true',
              token: admin.token))
          .rows
          .single as Map;
      final from = year['start_date'] as String;
      final to = year['end_date'] as String;

      final refused = await _call(
          'POST', '/rest/v1/rpc/servant_activity_summary',
          token: servant.token, body: {'p_from': from, 'p_to': to});
      expect(refused.ok, isFalse);

      final r = await _call('POST', '/rest/v1/rpc/servant_activity_summary',
          token: admin.token, body: {'p_from': from, 'p_to': to});
      expect(r.ok, isTrue, reason: '${r.body}');
      final row = (r.rows.firstWhere((x) => x['servant_id'] == servant.id)
          as Map);

      final marks = await _call(
          'GET',
          '/rest/v1/servant_attendances?select=activity_type'
              '&servant_id=eq.${servant.id}&date=gte.$from&date=lte.$to',
          token: admin.token);
      int count(String type) =>
          marks.rows.where((m) => m['activity_type'] == type).length;
      expect(row['sunday_school'], count('sunday_school'));
      expect(row['servant_meeting'], count('servant_meeting'));
      expect(row['mass'], count('mass'));
      expect(row['confession'], count('confession'));

      final preps = await _call(
          'GET',
          '/rest/v1/servant_lesson_preps?select=status,'
              'attendance_sessions!inner(session_date,is_break)'
              '&servant_id=eq.${servant.id}'
              '&attendance_sessions.session_date=gte.$from'
              '&attendance_sessions.session_date=lte.$to'
              '&attendance_sessions.is_break=eq.false',
          token: admin.token);
      expect(row['preps_total'], preps.rows.length);
      expect(row['preps_pending'],
          preps.rows.where((p) => p['status'] == 'pending').length);
      expect(row['classes_count'], 1);
    });
  });

  group('signed-out callers', () {
    const zero = '00000000-0000-0000-0000-000000000000';

    dev('cannot call the functions that were open to them', () async {
      // 42501: refused before the function runs.
      final sessions = await _call(
          'POST', '/rest/v1/rpc/generate_sessions_internal',
          body: {'p_year_id': zero});
      expect(sessions.code, '42501', reason: '${sessions.body}');
      final totals = await _call(
          'POST', '/rest/v1/rpc/service_weekly_attendance',
          body: {'p_year': zero, 'p_from': '2026-01-01'});
      expect(totals.code, '42501', reason: '${totals.body}');
      // PGRST202: no such function any more.
      final email = await _call(
          'POST', '/rest/v1/rpc/check_email_registered',
          body: {'p_email': 'nobody@sabtawya.test'});
      expect(email.code, 'PGRST202', reason: '${email.body}');
    });

    dev('can still check a name and an email before signing up', () async {
      final name = await _call('POST', '/rest/v1/rpc/servant_name_taken',
          body: {'p_name': 'nobody at all'});
      final email = await _call('POST', '/rest/v1/rpc/check_signup_email',
          body: {'p_email': 'someone@gmail.com'});
      expect(name.body, isFalse, reason: '${name.body}');
      expect(email.ok, isTrue, reason: '${email.body}');
    });

    dev('signed in, the admin still creates sessions and a servant still reads '
        'the totals', () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final year = (await _call(
              'GET', '/rest/v1/attendance_years?select=id&is_current=eq.true',
              token: admin.token))
          .rows
          .single['id'];
      final made = await _call(
          'POST', '/rest/v1/rpc/generate_sessions_for_year',
          token: admin.token, body: {'p_year_id': year});
      expect(made.ok, isTrue, reason: '${made.body}');
      final direct = await _call(
          'POST', '/rest/v1/rpc/generate_sessions_internal',
          token: servant.token, body: {'p_year_id': year});
      expect(direct.code, '42501', reason: '${direct.body}');
      final totals = await _call(
          'POST', '/rest/v1/rpc/service_weekly_attendance',
          token: servant.token,
          body: {'p_year': year, 'p_from': '2026-01-01'});
      expect(totals.ok, isTrue, reason: '${totals.body}');
    });
  });

  group('a deactivated servant and event money', () {
    dev('reads and adds payments only while active', () async {
      final admin = await _login('admin');
      final servant = await _login('servant');
      final kids = await _call(
          'GET',
          '/rest/v1/children?select=id&is_active=eq.true&order=full_name&limit=2',
          token: servant.token);
      final paid = kids.rows[0]['id'] as String;
      final other = kids.rows[1]['id'] as String;
      final made = await _call('POST', '/rest/v1/events',
          token: admin.token,
          body: {
            'title': 'dev security test',
            'event_date': '2099-01-01',
            'cost': 100,
            'created_by': admin.id,
          },
          prefer: 'return=representation');
      expect(made.ok, isTrue, reason: '${made.body}');
      final event = made.rows.single['id'] as String;

      Future<_Reply> pay(String child) =>
          _call('POST', '/rest/v1/event_payments',
              token: servant.token,
              body: {
                'event_id': event,
                'child_id': child,
                'amount': 10,
                'paid_by': servant.id,
              });
      Future<_Reply> reserve(String child) =>
          _call('POST', '/rest/v1/event_reservations',
              token: servant.token,
              body: {
                'event_id': event,
                'child_id': child,
                'reserved_by': servant.id,
              });
      Future<int> seen(String table, _Who who) async => (await _call(
              'GET',
              '/rest/v1/$table?select=*&'
                  '${table == 'events' ? 'id' : 'event_id'}=eq.$event',
              token: who.token))
          .rows
          .length;

      try {
        expect((await pay(paid)).ok, isTrue);
        expect((await reserve(paid)).ok, isTrue);
        for (final t in ['events', 'event_payments', 'event_reservations']) {
          expect(await seen(t, servant), 1, reason: 'active: $t');
        }

        await _call('PATCH', '/rest/v1/profiles?id=eq.${servant.id}',
            token: admin.token, body: {'is_active': false});
        for (final t in ['events', 'event_payments', 'event_reservations']) {
          expect(await seen(t, servant), 0, reason: 'deactivated: $t');
        }
        expect((await pay(other)).ok, isFalse);
        expect((await reserve(other)).ok, isFalse);
        // Their own rows cannot be removed either.
        for (final t in ['event_payments', 'event_reservations']) {
          await _call('DELETE', '/rest/v1/$t?event_id=eq.$event',
              token: servant.token);
          expect(await seen(t, admin), 1, reason: 'kept: $t');
        }
      } finally {
        await _call('PATCH', '/rest/v1/profiles?id=eq.${servant.id}',
            token: admin.token, body: {'is_active': true});
        await _call('DELETE', '/rest/v1/events?id=eq.$event',
            token: admin.token);
        for (final who in [admin, servant, await _login('general')]) {
          await _call(
              'DELETE',
              '/rest/v1/notifications?kind=in.(event_added,app_update)'
                  '&created_at=gte.$started',
              token: who.token);
        }
      }
    });
  });
}

/// Uploads a tiny PDF to [bucket]/[path] as the holder of [token].
Future<_Reply> _upload(String bucket, String path, String token) async {
  final r = await http.post(
    Uri.parse('$_base/storage/v1/object/$bucket/$path'),
    headers: {
      'apikey': _key!,
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/pdf',
      'x-upsert': 'true',
    },
    body: utf8.encode('%PDF-1.4\n%dev test\n'),
  );
  dynamic body;
  try {
    body = jsonDecode(r.body);
  } catch (_) {
    body = r.body;
  }
  return _Reply(r.statusCode, body);
}

/// Reads [bucket]/[path] as the holder of [token].
Future<_Reply> _download(String bucket, String path, String token) async {
  final r = await http.get(
    // A fresh query each time, so a cached answer from before a policy
    // change is not what is checked.
    Uri.parse('$_base/storage/v1/object/authenticated/$bucket/$path'
        '?t=${DateTime.now().microsecondsSinceEpoch}'),
    headers: {'apikey': _key!, 'Authorization': 'Bearer $token'},
  );
  return _Reply(r.statusCode, null);
}
