import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _boxHttp = 'http_cache_v1';
const _boxQueue = 'write_queue_v2';
const _boxFailed = 'write_failed_v2';

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
  final String? error;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'method': method,
        'url': url,
        'headers': headers,
        'body': bodyBase64,
        'label': label,
        'created_at': createdAt.toIso8601String(),
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
        error: message,
      );
}

/// Local storage behind offline mode: the last good copy of every read, the
/// queue of writes made offline, and the writes the server refused.
class OfflineStore {
  const OfflineStore._();

  /// How many writes are waiting, so the UI can show and react to it.
  static final ValueNotifier<int> pending = ValueNotifier<int>(0);

  static Future<void> init() async {
    // The first version queued attendance only; its boxes are gone.
    for (final old in const ['attendance_cache', 'write_queue']) {
      try {
        await Hive.deleteBoxFromDisk(old);
      } catch (_) {}
    }
    try {
      await _openAll();
    } catch (_) {
      for (final name in const [_boxHttp, _boxQueue, _boxFailed]) {
        try {
          await Hive.deleteBoxFromDisk(name);
        } catch (_) {}
      }
      try {
        await _openAll();
      } catch (_) {}
    }
    pending.value = pendingCount();
  }

  static Future<void> _openAll() async {
    await Hive.openBox<dynamic>(_boxHttp);
    await Hive.openBox<dynamic>(_boxQueue);
    await Hive.openBox<dynamic>(_boxFailed);
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

  static int pendingCount() => _box(_boxQueue)?.length ?? 0;

  static Future<void> enqueue(QueuedRequest request) async {
    await _box(_boxQueue)?.put(request.id, request.toMap());
    pending.value = pendingCount();
  }

  /// Oldest first.
  static List<QueuedRequest> pendingWrites() {
    final box = _box(_boxQueue);
    if (box == null) return const <QueuedRequest>[];
    return box.values.map((raw) => QueuedRequest.fromMap(raw as Map)).toList()
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

  static List<QueuedRequest> failedWrites() {
    final box = _box(_boxFailed);
    if (box == null) return const <QueuedRequest>[];
    return box.values.map((raw) => QueuedRequest.fromMap(raw as Map)).toList()
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
    ));
  }
}
