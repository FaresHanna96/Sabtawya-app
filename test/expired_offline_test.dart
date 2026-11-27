// Offline once the sign-in has expired: kept answers must still be read and
// saves still queued.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabtawya/core/services/connectivity_service.dart';
import 'package:sabtawya/core/services/offline_http_client.dart';
import 'package:sabtawya/core/services/offline_store.dart';
import 'package:sabtawya/data/supabase/db.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _jwt(int exp) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': 'u1', 'exp': exp})}.x';
}

String _session(DateTime expires) {
  final exp = expires.millisecondsSinceEpoch ~/ 1000;
  return jsonEncode({
    'access_token': _jwt(exp),
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'r',
    'user': {
      'id': 'u1',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

void main() {
  late Directory dir;
  late SupabaseClient client;
  var online = true;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('expired');
    Hive.init(dir.path);
    await OfflineStore.init(cipherProvider: () async => null);
    online = true;
    final inner = OfflineHttpClient(MockClient((request) async {
      if (!online) throw http.ClientException('Failed to fetch');
      return http.Response('[{"id":"a","full_name":"Anna"}]', 200,
          headers: {'content-type': 'application/json'}, request: request);
    }));
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: inner,
      postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    Db.testClient = client;
    Db.offlineHttp = inner;
    ConnectivityService.instance.markOnline();
  });

  tearDown(() async {
    Db.testClient = null;
    Db.offlineHttp = null;
    ConnectivityService.instance.markOnline();
    await client.dispose();
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('kept answers are read and saves queued', () async {
    // Read once while the sign-in is good.
    await client.auth.setInitialSession(
        _session(DateTime.now().add(const Duration(hours: 1))));
    expect(await Db.from('children').select(), hasLength(1));

    // An hour later, with no connection. The same person, so the same cache.
    await client.auth.setInitialSession(
        _session(DateTime.now().subtract(const Duration(minutes: 5))));
    online = false;

    // The library alone refuses before the offline layer is reached.
    await expectLater(
        client.from('children').select(), throwsA(isA<AuthException>()));
    expect(ConnectivityService.instance.isOnline, isFalse);

    final kept = await Db.from('children').select();
    expect(kept.single['full_name'], 'Anna');

    await Db.from('attendance_records').upsert(
        {'session_id': 's', 'child_id': 'a', 'mass': true},
        onConflict: 'session_id,child_id');
    expect(OfflineStore.pendingCount(forUser: 'u1'), 1);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a good sign-in goes the normal way even when marked offline', () async {
    await client.auth.setInitialSession(
        _session(DateTime.now().add(const Duration(hours: 1))));
    ConnectivityService.instance.markOffline();
    expect(await Db.from('children').select(), hasLength(1));
    expect(ConnectivityService.instance.isOnline, isTrue);
  });
}
