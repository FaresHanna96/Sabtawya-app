import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabtawya/core/services/offline_store.dart';
import 'package:sabtawya/core/services/sync_service.dart';

const _base = 'https://example.supabase.co/rest/v1';

class _Sent {
  _Sent(this.method, this.path, this.token, this.body);
  final String method;
  final String path;
  final String token;
  final String body;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  final sent = <_Sent>[];

  /// What the server answers, by the order of the request; null throws a
  /// connection error. Defaults to 201 for everything.
  late http.Response? Function(int index, http.BaseRequest request) answer;
  String? user = 'user-a';
  String? token = 'token-1';
  var synced = 0;

  SyncService makeService() => SyncService(
        client: MockClient((request) async {
          final i = sent.length;
          sent.add(_Sent(
            request.method,
            request.url.path,
            request.headers['Authorization'] ?? '',
            utf8.decode(request.bodyBytes),
          ));
          final r = answer(i, request);
          if (r == null) throw http.ClientException('Failed to fetch');
          return r;
        }),
        userId: () => user,
        accessToken: () => token,
        autoStart: false,
      );

  Future<void> queue(String label, {String? owner, String body = '{}'}) =>
      OfflineStore.enqueue(QueuedRequest(
        id: OfflineStore.nextId(),
        method: 'POST',
        url: '$_base/$label',
        headers: const {'content-type': 'application/json'},
        bodyBase64: base64Encode(utf8.encode(body)),
        label: label,
        createdAt: DateTime.now(),
        user: owner,
      ));

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('sync_test');
    Hive.init(dir.path);
    await OfflineStore.init();
    sent.clear();
    answer = (_, __) => http.Response('', 201);
    user = 'user-a';
    token = 'token-1';
    synced = 0;
    SyncService.onSynced = () => synced++;
  });

  tearDown(() async {
    SyncService.onSynced = null;
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('waiting writes are sent oldest first with the current token', () async {
    await queue('children', owner: 'user-a', body: '{"n":1}');
    await queue('event_payments', owner: 'user-a', body: '{"n":2}');
    await queue('classes', owner: 'user-a', body: '{"n":3}');

    await makeService().flush();

    expect(sent.map((s) => s.path.split('/').last),
        ['children', 'event_payments', 'classes']);
    expect(sent.map((s) => s.body), ['{"n":1}', '{"n":2}', '{"n":3}']);
    expect(sent.every((s) => s.token == 'Bearer token-1'), isTrue);
    expect(OfflineStore.pendingCount(), 0);
    expect(synced, 1);
  });

  test("only the signed-in person's writes are sent", () async {
    await queue('children', owner: 'user-b');
    await queue('classes', owner: 'user-a');

    await makeService().flush();

    expect(sent.map((s) => s.path.split('/').last), ['classes']);
    expect(OfflineStore.pendingWrites().single.user, 'user-b');
  });

  test('a write from an older version (no owner) is sent for whoever is in',
      () async {
    await queue('children');

    await makeService().flush();

    expect(sent, hasLength(1));
    expect(OfflineStore.pendingCount(), 0);
  });

  test('nobody signed in: nothing is sent', () async {
    await queue('children', owner: 'user-a');
    user = null;
    await makeService().flush();
    expect(sent, isEmpty);

    user = 'user-a';
    token = null;
    await makeService().flush();
    expect(sent, isEmpty);
    expect(OfflineStore.pendingCount(), 1);
  });

  test('an expired sign-in (401) stops the run and keeps every write',
      () async {
    await queue('children', owner: 'user-a');
    await queue('classes', owner: 'user-a');
    answer = (_, __) => http.Response('{"message":"JWT expired"}', 401);

    await makeService().flush();

    expect(sent, hasLength(1)); // the second waits behind the first
    expect(OfflineStore.pendingCount(), 2);
    expect(OfflineStore.failedWrites(), isEmpty);
    expect(synced, 0);
  });

  test('server trouble (500) stops the run and keeps every write', () async {
    await queue('children', owner: 'user-a');
    await queue('classes', owner: 'user-a');
    answer = (_, __) => http.Response('oops', 503);

    await makeService().flush();

    expect(sent, hasLength(1));
    expect(OfflineStore.pendingCount(), 2);
    expect(OfflineStore.failedWrites(), isEmpty);
  });

  for (final code in [408, 429]) {
    test('a $code is retried later, not set aside as failed', () async {
      await queue('children', owner: 'user-a');
      await queue('classes', owner: 'user-a');
      answer = (_, __) => http.Response('slow down', code);

      await makeService().flush();

      expect(sent, hasLength(1));
      expect(OfflineStore.pendingCount(), 2);
      expect(OfflineStore.failedWrites(), isEmpty);
    });
  }

  test('a lost connection stops the run and keeps every write', () async {
    await queue('children', owner: 'user-a');
    await queue('classes', owner: 'user-a');
    answer = (_, __) => null;

    await makeService().flush();

    expect(sent, hasLength(1));
    expect(OfflineStore.pendingCount(), 2);
    expect(synced, 0);
  });

  test('a refused write is set aside with the reason and the rest go on',
      () async {
    await queue('children', owner: 'user-a');
    await queue('classes', owner: 'user-a');
    answer = (i, _) => i == 0
        ? http.Response('{"message":"duplicate key"}', 409)
        : http.Response('', 201);

    await makeService().flush();

    expect(sent, hasLength(2));
    expect(OfflineStore.pendingCount(), 0);
    final failed = OfflineStore.failedWrites().single;
    expect(failed.label, 'children');
    expect(failed.error, '409 duplicate key');
    expect(failed.user, 'user-a');
    expect(synced, 1); // the second one did reach the server
  });

  test('the counts follow the signed-in person', () async {
    await queue('children', owner: 'user-a');
    await queue('classes', owner: 'user-b');
    final service = makeService();

    expect(service.pendingCount, 1);
    user = 'user-b';
    expect(service.pendingCount, 1);
    user = null;
    expect(service.pendingCount, 0);

    user = 'user-a';
    await OfflineStore.markFailed(
        OfflineStore.pendingWrites(forUser: 'user-a').single, '403');
    expect(service.failedCount, 1);
    user = 'user-b';
    expect(service.failedCount, 0);
  });

  test('a refused write retried goes back and is sent next time', () async {
    await queue('children', owner: 'user-a');
    answer = (_, __) => http.Response('{"message":"no"}', 400);
    final service = makeService();
    await service.flush();
    final id = OfflineStore.failedWrites().single.id;

    answer = (_, __) => http.Response('', 201);
    await service.retryFailed(id);
    await service.flush();

    expect(OfflineStore.pendingCount(), 0);
    expect(OfflineStore.failedWrites(), isEmpty);
    expect(sent, hasLength(2));
  });
}
