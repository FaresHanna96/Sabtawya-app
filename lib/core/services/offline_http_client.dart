import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_version.dart';
import 'connectivity_service.dart';
import 'offline_store.dart';

/// Makes the whole app work offline by sitting under the Supabase client.
///
/// * Reads (`GET /rest/v1/...`): the answer is kept; when the network is down
///   the last kept answer for the same request is returned instead.
/// * Writes (rows and storage uploads): when they cannot reach the server they
///   are queued in the order they were made, the kept answers are patched so
///   the screens show the change straight away, and a believable success is
///   returned. [SyncService] replays the queue when the connection is back.
///
/// Everything else (sign-in, edge functions) passes straight through and so
/// needs a connection.
class OfflineHttpClient extends http.BaseClient {
  OfflineHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  /// Used for replays, so a replayed write is never queued a second time.
  static final http.Client raw = http.Client();

  /// A slow connection should fall back to the kept copy, not spin forever.
  static const _readTimeout = Duration(seconds: 10);

  /// With nothing kept there is nothing to fall back to, so wait longer, then
  /// show the error with its retry button.
  static const _firstReadTimeout = Duration(seconds: 30);

  /// Tables whose primary key is a server-generated `id`; an insert made
  /// offline gets one here so later queued writes can refer to the new row.
  static const _idTables = <String>{
    'children',
    'child_visit_logs',
    'classes',
    'class_servants',
    'events',
    'event_payments',
    'competitions',
    'servant_lesson_preps',
    'servant_lesson_prep_photos',
    'servant_attendances',
    'attendance_years',
    'servant_invites',
    'message_templates',
    'lesson_materials',
  };

  /// Writes that must reach the server now or fail: a lesson prep and its
  /// files. Queued, the app said "sent" while the photos were still on the
  /// phone, and the prep showed up without them (or with broken ones). And a
  /// device removed at sign-out: replayed after the next sign-in, it would
  /// switch that person's pushes off.
  static const _neverQueueTables = <String>{
    'servant_lesson_preps',
    'servant_lesson_prep_photos',
    'device_tokens',
  };
  static const _neverQueueBuckets = <String>{'servant-submissions'};

  static const _reserved = <String>{
    'select',
    'order',
    'limit',
    'offset',
    'on_conflict',
    'columns',
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final method = request.method.toUpperCase();

    // The database can refuse builds below a minimum (app_build_gate): say which
    // build this is, on the header every Supabase request already carries (so the
    // browser's CORS rules already allow it).
    if (path.contains('/rest/v1/')) {
      final info = request.headers['x-client-info'] ?? 'supabase-flutter';
      if (!info.contains('sabtawya/')) {
        request.headers['x-client-info'] = '$info sabtawya/$kAppBuild';
      }
    }

    if (path.contains('/rest/v1/') && !path.contains('/rest/v1/rpc/')) {
      if (method == 'GET' || method == 'HEAD') return _read(request);
      if (_neverQueueTables.contains(_tableOf(path))) {
        return _inner.send(request);
      }
      return _write(request, _tableOf(path));
    }
    if (_isStorageUpload(path, method)) {
      final target = path.split('/storage/v1/object/').last;
      if (_neverQueueBuckets.contains(target.split('/').first)) {
        return _inner.send(request);
      }
      return _write(request, target);
    }
    if (path.contains('/auth/v1/')) {
      // A token refresh that cannot get through is how an expired sign-in
      // finds out there is no connection (see Db.from).
      try {
        return await _inner.send(request);
      } catch (e) {
        if (isNetworkError(e)) ConnectivityService.instance.markOffline();
        rethrow;
      }
    }
    return _inner.send(request);
  }

  // ── reads ──────────────────────────────────────────────────────────────────

  Future<http.StreamedResponse> _read(http.BaseRequest original) async {
    final request = await _materialize(original);
    final key = _cacheKey(request);
    final cached = OfflineStore.getCached(key);

    try {
      final streamed = await _inner
          .send(request)
          .timeout(cached != null ? _readTimeout : _firstReadTimeout);
      final response = await http.Response.fromStream(streamed);
      ConnectivityService.instance.markOnline();
      if (response.statusCode == 200 || response.statusCode == 206) {
        await OfflineStore.putCached(key, <String, dynamic>{
          'table': _tableOf(request.url.path),
          'url': request.url.toString(),
          'user': _userOf(request),
          'status': response.statusCode,
          'headers': <String, String>{
            'content-type':
                response.headers['content-type'] ?? 'application/json',
            if (response.headers['content-range'] != null)
              'content-range': response.headers['content-range']!,
          },
          'body': utf8.decode(response.bodyBytes),
        });
      }
      return _streamed(
        request,
        response.statusCode,
        response.bodyBytes,
        response.headers,
      );
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      ConnectivityService.instance.markOffline();
      if (cached == null) rethrow;
      return _streamed(
        request,
        cached['status'] as int? ?? 200,
        Uint8List.fromList(utf8.encode(cached['body'] as String)),
        Map<String, String>.from(cached['headers'] as Map),
      );
    }
  }

  // ── writes ─────────────────────────────────────────────────────────────────

  Future<http.StreamedResponse> _write(
    http.BaseRequest original,
    String label,
  ) async {
    final request = _withIds(await _materialize(original));

    // Keep the order: while this person's earlier writes are waiting, a later
    // one waits too, otherwise it could run before the row it depends on
    // exists. Somebody else's waiting writes do not hold this one back.
    if (OfflineStore.pendingCount(forUser: _userOf(request)) == 0) {
      try {
        final response = await _inner.send(request);
        ConnectivityService.instance.markOnline();
        return response;
      } catch (e) {
        if (!isNetworkError(e)) rethrow;
        ConnectivityService.instance.markOffline();
      }
    }
    return _enqueue(request, label);
  }

  /// Gives a plain insert its `id` before it is sent the first time. Should
  /// the answer be lost, the replay carries the same id, so the server refuses
  /// it as already saved instead of saving the row twice.
  http.Request _withIds(http.Request request) {
    final path = request.url.path;
    if (!path.contains('/rest/v1/') ||
        request.method.toUpperCase() != 'POST' ||
        request.url.queryParameters.containsKey('on_conflict') ||
        !_idTables.contains(_tableOf(path))) {
      return request;
    }
    final rows = _decodeRows(request.bodyBytes);
    if (rows.isEmpty) return request;
    for (final row in rows) {
      row.putIfAbsent('id', _uuid);
    }
    // A list insert names its columns; one left out of the list is ignored.
    var url = request.url;
    final columns = url.queryParameters['columns'];
    if (columns != null && !columns.split(',').contains('"id"')) {
      url = url.replace(queryParameters: <String, String>{
        ...url.queryParameters,
        'columns': '$columns,"id"',
      });
    }
    return http.Request(request.method, url)
      ..headers.addAll(request.headers)
      ..bodyBytes = Uint8List.fromList(utf8.encode(jsonEncode(
        _bodyIsList(request.bodyBytes) ? rows : rows.first,
      )))
      ..followRedirects = request.followRedirects
      ..persistentConnection = request.persistentConnection;
  }

  Future<http.StreamedResponse> _enqueue(
    http.Request request,
    String label,
  ) async {
    final isRest = request.url.path.contains('/rest/v1/');
    final table = _tableOf(request.url.path);
    final bytes = request.bodyBytes;
    final rows = isRest && request.method.toUpperCase() == 'POST'
        ? _decodeRows(bytes)
        : const <Map<String, dynamic>>[];

    final headers = Map<String, String>.from(request.headers)
      ..removeWhere((k, _) => k.toLowerCase() == 'authorization');
    await OfflineStore.enqueue(QueuedRequest(
      id: OfflineStore.nextId(),
      method: request.method.toUpperCase(),
      url: request.url.toString(),
      headers: headers,
      bodyBase64: base64Encode(bytes),
      label: label,
      createdAt: DateTime.now(),
      user: _userOf(request),
    ));

    if (!isRest) {
      return _json(request, 200, <String, dynamic>{
        'Key': label,
        'Id': _uuid(),
      });
    }

    final patch =
        request.method.toUpperCase() == 'PATCH' ? _decodeMap(bytes) : null;
    try {
      await _patchCaches(
        table: table,
        method: request.method.toUpperCase(),
        url: request.url,
        rows: rows,
        patch: patch,
        keepExisting:
            (request.headers['Prefer'] ?? request.headers['prefer'] ?? '')
                .contains('resolution=ignore-duplicates'),
      );
    } catch (_) {
      // A failed local patch must never lose the queued write.
    }
    return _synthetic(request, table, bytes, rows, patch);
  }

  http.StreamedResponse _synthetic(
    http.Request request,
    String table,
    Uint8List bytes,
    List<Map<String, dynamic>> rows,
    Map<String, dynamic>? patch,
  ) {
    final method = request.method.toUpperCase();
    final wantsRows =
        (request.headers['Prefer'] ?? request.headers['prefer'] ?? '')
            .contains('return=representation');
    final wantsObject =
        (request.headers['Accept'] ?? request.headers['accept'] ?? '')
            .contains('vnd.pgrst.object');

    if (!wantsRows || method == 'DELETE') {
      return _streamed(request, method == 'POST' ? 201 : 204, Uint8List(0),
          const <String, String>{});
    }

    List<Map<String, dynamic>> result;
    if (method == 'POST') {
      result = rows;
    } else {
      final base = _findCachedRow(table, request.url) ?? <String, dynamic>{};
      final id = request.url.queryParameters['id'];
      result = <Map<String, dynamic>>[
        <String, dynamic>{
          ...base,
          if (id != null && id.startsWith('eq.')) 'id': id.substring(3),
          ...?patch,
        },
      ];
    }
    return _json(
      request,
      method == 'POST' ? 201 : 200,
      wantsObject ? (result.isEmpty ? null : result.first) : result,
    );
  }

  // ── keeping the kept answers current ───────────────────────────────────────

  Future<void> _patchCaches({
    required String table,
    required String method,
    required Uri url,
    required List<Map<String, dynamic>> rows,
    required Map<String, dynamic>? patch,
    bool keepExisting = false,
  }) async {
    // A filter the kept answers cannot evaluate (or/and): do not guess, the
    // next online read corrects them.
    if (method != 'POST' &&
        (url.queryParameters.containsKey('or') ||
            url.queryParameters.containsKey('and'))) {
      return;
    }
    final writeFilters = _filtersOf(url);

    for (final entry in OfflineStore.cachedEntries().toList()) {
      final data = entry.value;
      final entryTable = data['table'] as String?;
      final entryUrl = Uri.parse(data['url'] as String);
      final entryFilters = _filtersOf(entryUrl);

      var changed = false;
      dynamic body;
      try {
        body = jsonDecode(data['body'] as String);
      } catch (_) {
        continue;
      }

      if (entryTable == table && body is List) {
        final list = body
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        if (method == 'POST') {
          for (final row in rows) {
            if (!_matches(row, entryFilters)) continue;
            final id = row['id'];
            final at = id == null ? -1 : list.indexWhere((r) => r['id'] == id);
            if (at >= 0) {
              list[at] = <String, dynamic>{...list[at], ...row};
            } else {
              list.add(Map<String, dynamic>.from(row));
            }
            changed = true;
          }
          if (changed) _sort(list, entryUrl.queryParameters['order']);
        } else if (method == 'PATCH' && patch != null) {
          for (var i = list.length - 1; i >= 0; i--) {
            if (!_matches(list[i], writeFilters, strict: true)) continue;
            final merged = <String, dynamic>{...list[i], ...patch};
            changed = true;
            if (_matches(merged, entryFilters)) {
              list[i] = merged;
            } else {
              list.removeAt(i);
            }
          }
        } else if (method == 'DELETE') {
          final before = list.length;
          list.removeWhere((r) => _matches(r, writeFilters, strict: true));
          changed = list.length != before;
        }
        body = list;
      } else if (entryTable == table &&
          body is Map &&
          method == 'PATCH' &&
          patch != null) {
        if (_matches(Map<String, dynamic>.from(body), writeFilters,
            strict: true)) {
          body = <String, dynamic>{...body, ...patch};
          changed = true;
        }
      } else if (table == 'attendance_records' &&
          entryTable == 'v_session_scores' &&
          method == 'POST' &&
          body is List) {
        changed = _patchScores(body, rows, entryFilters, keepExisting);
      }

      if (changed) {
        data['body'] = jsonEncode(body);
        await OfflineStore.putCached(entry.key, data);
      }
    }
  }

  /// An attendance upsert changes the marks the sheet reads from the scores
  /// view, so the sheet reopens with what the servant just saved. A save sends
  /// only the marks that changed, so only those are copied; with
  /// [keepExisting] (insert only if missing) a row already there is left alone.
  bool _patchScores(
    List<dynamic> list,
    List<Map<String, dynamic>> written,
    Map<String, String> entryFilters,
    bool keepExisting,
  ) {
    const flags = ['sunday_school', 'vespers', 'mass', 'confession'];
    var changed = false;
    for (final w in written) {
      final at = list.indexWhere((r) =>
          r is Map &&
          r['session_id'] == w['session_id'] &&
          r['child_id'] == w['child_id']);
      final now = DateTime.now().toIso8601String();
      if (at >= 0) {
        if (keepExisting) continue;
        list[at] = <String, dynamic>{
          ...Map<String, dynamic>.from(list[at] as Map),
          for (final f in flags)
            if (w.containsKey(f)) f: w[f],
          'updated_at': now,
        };
        changed = true;
        continue;
      }
      final record = <String, dynamic>{
        'session_id': w['session_id'],
        'child_id': w['child_id'],
        for (final f in flags) f: w[f] ?? false,
        'updated_at': now,
      };
      if (_matches(record, entryFilters)) {
        // The score is computed by the database; show the marks without one.
        list.add(<String, dynamic>{...record, 'score': 0, 'max_score': 20});
        changed = true;
      }
    }
    return changed;
  }

  Map<String, dynamic>? _findCachedRow(String table, Uri writeUrl) {
    final filters = _filtersOf(writeUrl);
    for (final entry in OfflineStore.cachedEntries()) {
      if (entry.value['table'] != table) continue;
      try {
        final body = jsonDecode(entry.value['body'] as String);
        final list = body is List ? body : <dynamic>[body];
        for (final r in list) {
          if (r is Map && _matches(Map<String, dynamic>.from(r), filters)) {
            return Map<String, dynamic>.from(r);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // ── PostgREST filter handling (just enough to keep kept answers right) ─────

  Map<String, String> _filtersOf(Uri url) => <String, String>{
        for (final e in url.queryParameters.entries)
          if (!_reserved.contains(e.key) && e.key != 'or' && e.key != 'and')
            e.key: e.value,
      };

  /// [strict]: a row that lacks a filter's column does not match. Used for a
  /// write's own filters, so a PATCH or DELETE never reaches rows of a kept
  /// list that did not select that column. A kept list's own filters stay
  /// lenient (cannot tell, so keep the row).
  bool _matches(Map<String, dynamic> row, Map<String, String> filters,
      {bool strict = false}) {
    for (final f in filters.entries) {
      if (!row.containsKey(f.key)) {
        if (strict) return false;
        continue;
      }
      if (!_test(row[f.key], f.value)) return false;
    }
    return true;
  }

  bool _test(dynamic actual, String expr) {
    var op = expr;
    var negate = false;
    if (op.startsWith('not.')) {
      negate = true;
      op = op.substring(4);
    }
    final dot = op.indexOf('.');
    if (dot < 0) return true;
    final name = op.substring(0, dot);
    final value = op.substring(dot + 1);
    final a = actual?.toString();
    bool result;
    switch (name) {
      case 'eq':
        result = a == value;
      case 'neq':
        result = a != value;
      case 'is':
        result = value == 'null' ? actual == null : a == value;
      case 'in':
        final items = value
            .replaceAll(RegExp(r'^\(|\)$'), '')
            .split(',')
            .map((s) => s.replaceAll('"', ''))
            .toSet();
        result = a != null && items.contains(a);
      case 'gt':
        result = _cmp(actual, value) > 0;
      case 'gte':
        result = _cmp(actual, value) >= 0;
      case 'lt':
        result = _cmp(actual, value) < 0;
      case 'lte':
        result = _cmp(actual, value) <= 0;
      default:
        return true;
    }
    return negate ? !result : result;
  }

  int _cmp(dynamic a, String b) {
    final an = num.tryParse('$a');
    final bn = num.tryParse(b);
    if (an != null && bn != null) return an.compareTo(bn);
    return '$a'.compareTo(b);
  }

  void _sort(List<Map<String, dynamic>> list, String? order) {
    if (order == null || order.isEmpty) return;
    final keys = order.split(',').map((part) {
      final bits = part.split('.');
      return (col: bits.first, desc: bits.length > 1 && bits[1] == 'desc');
    }).toList();
    list.sort((x, y) {
      for (final k in keys) {
        final a = x[k.col];
        final b = y[k.col];
        if (a == b) continue;
        if (a == null) return 1;
        if (b == null) return -1;
        final c = a is num && b is num ? a.compareTo(b) : '$a'.compareTo('$b');
        if (c != 0) return k.desc ? -c : c;
      }
      return 0;
    });
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  bool _isStorageUpload(String path, String method) {
    if (method != 'POST' && method != 'PUT') return false;
    if (!path.contains('/storage/v1/object/')) return false;
    final rest = path.split('/storage/v1/object/').last;
    const notUploads = ['list/', 'sign/', 'move', 'copy', 'upload/'];
    return !notUploads.any(rest.startsWith);
  }

  String _tableOf(String path) {
    final tail = path.split('/rest/v1/').last;
    return tail.split('?').first.split('/').first;
  }

  Future<http.Request> _materialize(http.BaseRequest r) async {
    final bytes = await r.finalize().toBytes();
    return http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = bytes
      ..followRedirects = r.followRedirects
      ..persistentConnection = r.persistentConnection;
  }

  String _userOf(http.BaseRequest r) {
    final auth = r.headers['Authorization'] ?? r.headers['authorization'] ?? '';
    final token = auth.replaceFirst('Bearer ', '');
    final parts = token.split('.');
    if (parts.length != 3) return 'anon';
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map;
      return '${payload['sub'] ?? 'anon'}';
    } catch (_) {
      return 'anon';
    }
  }

  /// A stable short key (Hive keys are limited to 255 characters).
  String _cacheKey(http.BaseRequest r) {
    final accept = r.headers['Accept'] ?? r.headers['accept'] ?? '';
    final range = r.headers['Range'] ?? r.headers['range'] ?? '';
    final prefer = r.headers['Prefer'] ?? r.headers['prefer'] ?? '';
    final raw = '${_userOf(r)}|${r.method}|${r.url}|$accept|$range|$prefer';
    return '${_fnv(raw, 0x811c9dc5)}${_fnv(raw, 0x01000193 ^ 0x9e3779b9)}';
  }

  String _fnv(String s, int seed) {
    var h = seed & 0xffffffff;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  bool _bodyIsList(Uint8List bytes) {
    try {
      return jsonDecode(utf8.decode(bytes)) is List;
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> _decodeRows(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
      if (decoded is Map) {
        return <Map<String, dynamic>>[Map<String, dynamic>.from(decoded)];
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _decodeMap(Uint8List bytes) {
    final rows = _decodeRows(bytes);
    return rows.isEmpty ? null : rows.first;
  }

  http.StreamedResponse _json(
      http.BaseRequest request, int status, Object? body) {
    return _streamed(
      request,
      status,
      Uint8List.fromList(utf8.encode(jsonEncode(body))),
      const <String, String>{'content-type': 'application/json'},
    );
  }

  http.StreamedResponse _streamed(
    http.BaseRequest request,
    int status,
    List<int> bytes,
    Map<String, String> headers,
  ) {
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      contentLength: bytes.length,
      request: request,
      headers: <String, String>{
        ...headers,
        'content-length': '${bytes.length}',
      }..remove('content-encoding'),
    );
  }

  static String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
        '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }

  /// True for failures of the connection itself (not for an HTTP error status).
  static bool isNetworkError(Object e) {
    if (e is TimeoutException || e is http.ClientException) return true;
    final text = '${e.runtimeType} $e';
    return text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Failed to fetch') ||
        text.contains('NetworkError') ||
        text.contains('Connection closed') ||
        text.contains('Connection refused') ||
        text.contains('AuthRetryableFetchException');
  }
}
