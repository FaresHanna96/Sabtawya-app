import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

// The boxes as the first versions kept them: plain files. Still used on the
// web (no keystore there) and when the keystore cannot be reached.
const _legacyHttp = 'http_cache_v1';
const _legacyQueue = 'write_queue_v2';
const _legacyFailed = 'write_failed_v2';

// The same boxes encrypted with a key held in the Android keystore.
const _secureHttp = 'http_cache_v1e';
const _secureQueue = 'write_queue_v2e';
const _secureFailed = 'write_failed_v2e';

const _keyName = 'sabtawya_local_data_key';

/// A write that could not reach the server and waits for the connection.
///
/// It is the raw HTTP request, so every kind of write (rows, uploads) replays
/// the same way, in the order the user made them.
class QueuedRequest {
  const QueuedRequest({
    required this.id,
    required this.method,
    required this.url,
    required this.headers,
    required this.bodyBase64,
    required this.label,
    required this.createdAt,
    this.user,
    this.error,
  });

  factory QueuedRequest.fromMap(Map<dynamic, dynamic> m) => QueuedRequest(
        id: m['id'] as String,
        method: m['method'] as String,
        url: m['url'] as String,
        headers: Map<String, String>.from(m['headers'] as Map),
        bodyBase64: m['body'] as String? ?? '',
        label: m['label'] as String? ?? '',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
        user: m['user'] as String?,
        error: m['error'] as String?,
      );

  final String id;
  final String method;
  final String url;
  final Map<String, String> headers;
  final String bodyBase64;

  /// What the write touches (a table or a storage object), for the sync list.
  final String label;
  final DateTime createdAt;

  /// Who made the write (their user id), so it is only ever sent as them.
  /// Null for writes queued before this was recorded.
  final String? user;
  final String? error;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'method': method,
        'url': url,
        'headers': headers,
        'body': bodyBase64,
        'label': label,
        'created_at': createdAt.toIso8601String(),
        if (user != null) 'user': user,
        if (error != null) 'error': error,
      };

  QueuedRequest withError(String message) => QueuedRequest(
        id: id,
        method: method,
        url: url,
        headers: headers,
        bodyBase64: bodyBase64,
        label: label,
        createdAt: createdAt,
        user: user,
        error: message,
      );
}

/// Local storage behind offline mode: the last good copy of every read, the
/// queue of writes made offline, and the writes the server refused.
class OfflineStore {
  const OfflineStore._();

  /// How many writes are waiting, so the UI can show and react to it.
  static final ValueNotifier<int> pending = ValueNotifier<int>(0);

  static String _boxHttp = _legacyHttp;
  static String _boxQueue = _legacyQueue;
  static String _boxFailed = _legacyFailed;

  /// True when the boxes on disk are encrypted.
  static bool get isEncrypted => _boxHttp == _secureHttp;

  /// The key lives in the Android keystore (through flutter_secure_storage),
  /// made on first use. Null when there is no keystore (the web) or it cannot
  /// be reached: the app then keeps working with the plain boxes.
  static Future<HiveCipher?> _keystoreCipher() async {
    if (kIsWeb) return null;
    try {
      const storage = FlutterSecureStorage();
      final stored = await storage.read(key: _keyName);
      if (stored != null) return HiveAesCipher(base64Url.decode(stored));
      final key = Hive.generateSecureKey();
      await storage.write(key: _keyName, value: base64Url.encode(key));
      return HiveAesCipher(key);
    } catch (_) {
      return null;
    }
  }

  /// [cipherProvider] is for tests; the app uses the keystore.
  static Future<void> init({
    Future<HiveCipher?> Function()? cipherProvider,
  }) async {
    // The first version queued attendance only; its boxes are gone.
    for (final old in const ['attendance_cache', 'write_queue']) {
      try {
        await Hive.deleteBoxFromDisk(old);
      } catch (_) {}
    }
    final cipher = await (cipherProvider ?? _keystoreCipher)();
    _boxHttp = cipher == null ? _legacyHttp : _secureHttp;
    _boxQueue = cipher == null ? _legacyQueue : _secureQueue;
    _boxFailed = cipher == null ? _legacyFailed : _secureFailed;
    try {
      await _openAll(cipher);
    } catch (_) {
      // Unreadable (or the key was lost): start the boxes again.
      for (final name in [_boxHttp, _boxQueue, _boxFailed]) {
        try {
          await Hive.deleteBoxFromDisk(name);
        } catch (_) {}
      }
      try {
        await _openAll(cipher);
      } catch (_) {}
    }
    if (cipher != null) await _moveLegacyIntoEncrypted();
    pending.value = pendingCount();
  }

  static Future<void> _openAll(HiveCipher? cipher) async {
    await Hive.openBox<dynamic>(_boxHttp, encryptionCipher: cipher);
    await Hive.openBox<dynamic>(_boxQueue, encryptionCipher: cipher);
    await Hive.openBox<dynamic>(_boxFailed, encryptionCipher: cipher);
  }

  /// The first run with encryption: the writes still waiting (and the ones the
  /// server refused) move over, then every plain file is deleted. The kept
  /// reads are not moved; they are fetched again.
  static Future<void> _moveLegacyIntoEncrypted() async {
    for (final (from, to) in [
      (_legacyQueue, _boxQueue),
      (_legacyFailed, _boxFailed),
    ]) {
      try {
        if (!await Hive.boxExists(from)) continue;
        final old = await Hive.openBox<dynamic>(from);
        final target = Hive.box<dynamic>(to);
        for (final key in old.keys) {
          await target.put(key, old.get(key));
        }
        await old.close();
        await Hive.deleteBoxFromDisk(from);
      } catch (_) {
        // Left in place; tried again at the next start.
      }
    }
    try {
      if (await Hive.boxExists(_legacyHttp)) {
        await Hive.deleteBoxFromDisk(_legacyHttp);
      }
    } catch (_) {}
  }

  static Box<dynamic>? _box(String name) =>
      Hive.isBoxOpen(name) ? Hive.box<dynamic>(name) : null;

  // ── read cache ─────────────────────────────────────────────────────────────

  static Map<String, dynamic>? getCached(String key) {
    final v = _box(_boxHttp)?.get(key);
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  static Future<void> putCached(String key, Map<String, dynamic> entry) async {
    await _box(_boxHttp)?.put(key, entry);
  }

  static Iterable<MapEntry<String, Map<String, dynamic>>>
      cachedEntries() sync* {
    final box = _box(_boxHttp);
    if (box == null) return;
    for (final key in box.keys) {
      final v = box.get(key);
      if (v is Map) {
        yield MapEntry(key as String, Map<String, dynamic>.from(v));
      }
    }
  }

  /// Forgets every cached read (sign-out on a shared device). Queued writes stay.
  static Future<void> clearCache() async => _box(_boxHttp)?.clear();

  static Future<void> removeCached(String key) async =>
      _box(_boxHttp)?.delete(key);

  // ── write queue ────────────────────────────────────────────────────────────

  /// How many writes are waiting: all of them, or with [forUser] only that
  /// person's (and the ones with no recorded owner).
  static int pendingCount({String? forUser}) => forUser == null
      ? _box(_boxQueue)?.length ?? 0
      : pendingWrites(forUser: forUser).length;

  static int _lastId = 0;

  /// A queue id: the time in microseconds, never the same twice and always
  /// higher than the one before. The clock alone is not enough: on the web it
  /// moves in milliseconds, so two writes made together got the same id and
  /// the second replaced the first.
  static String nextId([DateTime? now]) {
    final micros = (now ?? DateTime.now()).microsecondsSinceEpoch;
    _lastId = micros > _lastId ? micros : _lastId + 1;
    return '$_lastId';
  }

  static bool _ownedBy(QueuedRequest r, String? user) =>
      user == null || r.user == null || r.user == user;

  static Future<void> enqueue(QueuedRequest request) async {
    await _box(_boxQueue)?.put(request.id, request.toMap());
    pending.value = pendingCount();
  }

  /// Oldest first. With [forUser], only that person's writes.
  static List<QueuedRequest> pendingWrites({String? forUser}) {
    final box = _box(_boxQueue);
    if (box == null) return const <QueuedRequest>[];
    return box.values
        .map((raw) => QueuedRequest.fromMap(raw as Map))
        .where((r) => _ownedBy(r, forUser))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  static Future<void> removeWrite(String id) async {
    await _box(_boxQueue)?.delete(id);
    pending.value = pendingCount();
  }

  // ── writes the server refused ──────────────────────────────────────────────

  static Future<void> markFailed(QueuedRequest request, String error) async {
    await _box(_boxFailed)?.put(request.id, request.withError(error).toMap());
    await removeWrite(request.id);
  }

  static List<QueuedRequest> failedWrites({String? forUser}) {
    final box = _box(_boxFailed);
    if (box == null) return const <QueuedRequest>[];
    return box.values
        .map((raw) => QueuedRequest.fromMap(raw as Map))
        .where((r) => _ownedBy(r, forUser))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  static Future<void> discardFailed(String id) async =>
      _box(_boxFailed)?.delete(id);

  /// Puts a refused write back at its original place in the queue.
  static Future<void> retryFailed(String id) async {
    final raw = _box(_boxFailed)?.get(id);
    if (raw is! Map) return;
    final request = QueuedRequest.fromMap(raw);
    await _box(_boxFailed)?.delete(id);
    await enqueue(QueuedRequest(
      id: request.id,
      method: request.method,
      url: request.url,
      headers: request.headers,
      bodyBase64: request.bodyBase64,
      label: request.label,
      createdAt: request.createdAt,
      user: request.user,
    ));
  }
}
