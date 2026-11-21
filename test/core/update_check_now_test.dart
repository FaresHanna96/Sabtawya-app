import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabtawya/core/services/update_service.dart';

http.Client _serving(Object body, {int status = 200, List<Uri>? asked}) =>
    MockClient((req) async {
      asked?.add(req.url);
      return http.Response.bytes(
        utf8.encode(body is String ? body : jsonEncode(body)),
        status,
      );
    });

void main() {
  const v = {'version': '1.0.51', 'build': 52};

  test('a newer build is available', () async {
    final r = await UpdateService.checkNow(
      client: _serving(v),
      web: false,
      current: 51,
    );
    expect(r.status, UpdateStatus.available);
    expect(r.update!.version, '1.0.51');
  });

  test('the same build is up to date', () async {
    final r = await UpdateService.checkNow(
      client: _serving(v),
      web: false,
      current: 52,
    );
    expect(r.status, UpdateStatus.upToDate);
    expect(r.update, isNull);
  });

  test('Flutter\'s own version.json (dev site) is read too', () async {
    final flutters = {
      'app_name': 'sabtawya',
      'version': '1.0.51',
      'build_number': '52',
    };
    final newer = await UpdateService.checkNow(
      client: _serving(flutters),
      web: true,
      current: 51,
    );
    expect(newer.status, UpdateStatus.available);
    final same = await UpdateService.checkNow(
      client: _serving(flutters),
      web: true,
      current: 52,
    );
    expect(same.status, UpdateStatus.upToDate);
  });

  test('a missing or broken file is a failed check, not "up to date"',
      () async {
    for (final client in [
      _serving(v, status: 404),
      _serving('<html>not json</html>'),
      _serving({'version': '1.0.51'}), // no build
      MockClient((_) async => throw http.ClientException('offline')),
    ]) {
      final r = await UpdateService.checkNow(
        client: client,
        web: false,
        current: 51,
      );
      expect(r.status, UpdateStatus.failed);
    }
  });

  test('the website reads its own version.json, never a cached copy', () async {
    final asked = <Uri>[];
    await UpdateService.checkNow(
      client: _serving(v, asked: asked),
      web: true,
      current: 51,
    );
    expect(asked.single.pathSegments.last, 'version.json');
    expect(asked.single.host, isNot('sabtawya.vercel.app'));
    expect(asked.single.queryParameters, contains('t'));
  });
}
