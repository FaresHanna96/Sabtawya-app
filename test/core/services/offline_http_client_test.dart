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
}
