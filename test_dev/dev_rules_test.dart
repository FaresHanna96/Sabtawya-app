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
