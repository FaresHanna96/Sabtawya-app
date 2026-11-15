import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabtawya/core/services/offline_http_client.dart';
import 'package:sabtawya/core/services/offline_store.dart';

const _base = 'https://example.supabase.co/rest/v1';

void main() {
  late Directory dir;
  var online = true;
  late OfflineHttpClient client;
  final sent = <String>[];

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('offline_test');
    Hive.init(dir.path);
    await OfflineStore.init();
    online = true;
    sent.clear();
    client = OfflineHttpClient(MockClient((request) async {
      if (!online) throw http.ClientException('Failed to fetch');
      sent.add('${request.method} ${request.url.path}');
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {
              'id': 'a',
              'class_id': 'c1',
              'full_name': 'Anna',
              'is_active': true
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('', 201);
    }));
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  Future<List<dynamic>> getChildren() async {
    final response = await client.get(
      Uri.parse(
          '$_base/children?class_id=eq.c1&is_active=eq.true&order=full_name'),
    );
    return jsonDecode(response.body) as List<dynamic>;
  }

  test('a read is answered from the last good copy when offline', () async {
    expect(await getChildren(), hasLength(1));
    online = false;
    final offline = await getChildren();
    expect(offline.single['full_name'], 'Anna');
  });

  test('a read with nothing kept still fails offline', () async {
    online = false;
    expect(getChildren, throwsA(isA<http.ClientException>()));
  });

  test('an insert made offline is queued, gets an id and shows up at once',
      () async {
    await getChildren();
    online = false;

    final response = await client.post(
      Uri.parse('$_base/children'),
      headers: {
        'content-type': 'application/json',
        'Prefer': 'return=representation',
        'Accept': 'application/vnd.pgrst.object+json',
      },
      body: jsonEncode({
        'class_id': 'c1',
        'full_name': 'Bola',
        'is_active': true,
      }),
    );

    expect(response.statusCode, 201);
    final created = jsonDecode(response.body) as Map<String, dynamic>;
    expect(created['id'], isNotEmpty);
    expect(OfflineStore.pendingCount(), 1);

    final list = await getChildren();
    expect(list.map((r) => r['full_name']), ['Anna', 'Bola']);
  });

  test('an update and a delete made offline patch the kept lists', () async {
    await getChildren();
    online = false;

    await client.patch(
      Uri.parse('$_base/children?id=eq.a'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'full_name': 'Anna M'}),
    );
    expect((await getChildren()).single['full_name'], 'Anna M');

    await client.patch(
      Uri.parse('$_base/children?id=eq.a'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'is_active': false}),
    );
    expect(await getChildren(), isEmpty); // left the active list

    expect(OfflineStore.pendingCount(), 2);
  });

  test('writes keep their order: later ones wait behind queued ones', () async {
    online = false;
    await client.post(
      Uri.parse('$_base/children'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'class_id': 'c1', 'full_name': 'First'}),
    );
    online = true; // back online, but the first write has not synced yet

    await client.post(
      Uri.parse('$_base/event_payments'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'child_id': 'x', 'amount': 5}),
    );

    expect(sent.where((s) => s.startsWith('POST')), isEmpty);
    final queued = OfflineStore.pendingWrites();
    expect(queued.map((q) => q.label), ['children', 'event_payments']);
  });

  test('a storage upload made offline is queued and reports success', () async {
    online = false;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://example.supabase.co/storage/v1/object/photos/a/b.jpg'),
    )..files.add(
        http.MultipartFile.fromBytes('file', [1, 2, 3], filename: 'b.jpg'));

    final streamed = await client.send(request);
    expect(streamed.statusCode, 200);
    expect(OfflineStore.pendingWrites().single.label, 'photos/a/b.jpg');
  });

  test('a refused write is set aside, not lost, and can be retried', () async {
    online = false;
    await client.post(
      Uri.parse('$_base/children'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'class_id': 'c1', 'full_name': 'X'}),
    );
    final write = OfflineStore.pendingWrites().single;

    await OfflineStore.markFailed(write, '409 duplicate');
    expect(OfflineStore.pendingCount(), 0);
    expect(OfflineStore.failedWrites().single.error, '409 duplicate');

    await OfflineStore.retryFailed(write.id);
    expect(OfflineStore.pendingCount(), 1);
    expect(OfflineStore.failedWrites(), isEmpty);
  });

  // ── queue ids and owners ───────────────────────────────────────────────────

  test('two ids asked for at the same instant differ and stay in order', () {
    final now = DateTime.now().add(const Duration(days: 1));
    final first = OfflineStore.nextId(now);
    final second = OfflineStore.nextId(now);

    expect(second, isNot(first));
    expect(second.compareTo(first), greaterThan(0));
  });

  test('writes made together are all kept (none replaces another)', () async {
    online = false;
    await Future.wait([
      for (var i = 0; i < 50; i++)
        client.post(
          Uri.parse('$_base/children'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'class_id': 'c1', 'full_name': 'Child $i'}),
        ),
    ]);

    expect(OfflineStore.pendingCount(), 50);
  });

  String jwtFor(String userId) {
    String part(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    return '${part({'alg': 'HS256'})}.${part({'sub': userId})}.sig';
  }

  Future<void> offlineInsertAs(String userId, String name) => client.post(
        Uri.parse('$_base/children'),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer ${jwtFor(userId)}',
        },
        body: jsonEncode({'class_id': 'c1', 'full_name': name}),
      );

  test('a queued write remembers who made it and is only theirs', () async {
    online = false;
    await offlineInsertAs('user-a', 'From A');
    await offlineInsertAs('user-b', 'From B');

    expect(OfflineStore.pendingCount(), 2);
    expect(OfflineStore.pendingWrites(forUser: 'user-a').single.user, 'user-a');
    expect(OfflineStore.pendingCount(forUser: 'user-b'), 1);
    expect(OfflineStore.pendingCount(forUser: 'user-c'), 0);
    // The sign-in token itself is never kept on the device.
    expect(
      OfflineStore.pendingWrites()
          .expand((w) => w.headers.keys)
          .map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
    );
  });

  test('a write queued by an older version (no owner) goes to whoever is in',
      () async {
    await OfflineStore.enqueue(QueuedRequest(
      id: OfflineStore.nextId(),
      method: 'POST',
      url: '$_base/children',
      headers: const {},
      bodyBase64: '',
      label: 'children',
      createdAt: DateTime.now(),
    ));

    expect(OfflineStore.pendingCount(forUser: 'anyone'), 1);
  });

  test("another person's waiting write does not hold mine back", () async {
    online = false;
    await offlineInsertAs('user-a', 'From A');
    online = true;

    await offlineInsertAs('user-b', 'From B');

    // B's write went straight to the server; A's still waits for A.
    expect(sent.where((s) => s.startsWith('POST')), hasLength(1));
    expect(OfflineStore.pendingWrites().single.user, 'user-a');
  });

  test('the owner survives being refused and retried', () async {
    online = false;
    await offlineInsertAs('user-a', 'From A');
    final write = OfflineStore.pendingWrites().single;

    await OfflineStore.markFailed(write, '403');
    expect(OfflineStore.failedWrites(forUser: 'user-a').single.user, 'user-a');
    expect(OfflineStore.failedWrites(forUser: 'user-b'), isEmpty);

    await OfflineStore.retryFailed(write.id);
    expect(OfflineStore.pendingWrites(forUser: 'user-a'), hasLength(1));
  });

  // ── attendance saved offline ───────────────────────────────────────────────

  group('attendance saved offline', () {
    const scoresUrl = '$_base/v_session_scores?session_id=eq.s1';

    late OfflineHttpClient sheet;

    setUp(() {
      sheet = OfflineHttpClient(MockClient((request) async {
        if (!online) throw http.ClientException('Failed to fetch');
        return http.Response(
          jsonEncode([
            {
              'session_id': 's1',
              'child_id': 'a',
              'sunday_school': false,
              'vespers': true,
              'mass': false,
              'confession': false,
              'score': 5,
              'max_score': 20,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));
    });

    Future<List<dynamic>> scores() async =>
        jsonDecode((await sheet.get(Uri.parse(scoresUrl))).body)
            as List<dynamic>;

    Future<void> upsert(List<Map<String, dynamic>> rows, String prefer) =>
        sheet.post(
          Uri.parse(
              '$_base/attendance_records?on_conflict=session_id%2Cchild_id'),
          headers: {'content-type': 'application/json', 'Prefer': prefer},
          body: jsonEncode(rows),
        );

    test('a changed mark keeps the other marks of that child', () async {
      await scores();
      online = false;

      await upsert([
        {'session_id': 's1', 'child_id': 'a', 'mass': true},
      ], 'resolution=merge-duplicates');

      final row = (await scores()).single as Map<String, dynamic>;
      expect(row['mass'], isTrue);
      expect(row['vespers'], isTrue); // not sent, so not wiped
      expect(row['sunday_school'], isFalse);
    });

    test('a new child shows with the unsent marks off', () async {
      await scores();
      online = false;

      await upsert([
        {'session_id': 's1', 'child_id': 'b', 'vespers': true},
      ], 'resolution=merge-duplicates');

      final row = (await scores()).firstWhere((r) => r['child_id'] == 'b')
          as Map<String, dynamic>;
      expect(row['vespers'], isTrue);
      expect(row['mass'], isFalse);
      expect(row['sunday_school'], isFalse);
      expect(row['confession'], isFalse);
    });

    test('insert-if-missing adds the absent child, never touches a saved one',
        () async {
      await scores();
      online = false;

      await upsert([
        {'session_id': 's1', 'child_id': 'a'},
        {'session_id': 's1', 'child_id': 'b'},
      ], 'resolution=ignore-duplicates');

      final list = await scores();
      expect(list, hasLength(2));
      final a = list.firstWhere((r) => r['child_id'] == 'a');
      expect(a['vespers'], isTrue); // the saved row is as it was
      final b = list.firstWhere((r) => r['child_id'] == 'b');
      expect(b['vespers'], isFalse);
    });
  });
}
