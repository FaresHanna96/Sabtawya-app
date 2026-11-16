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
          '/rest/v1/notifications?select=kind,title,body,ref_id'
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
      expect(r.body, {'inserted': 2, 'updated': 1});
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
}
