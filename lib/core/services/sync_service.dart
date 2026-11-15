import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connectivity_service.dart';
import 'offline_http_client.dart';
import 'offline_store.dart';

/// Replays the writes made offline, in order, whenever the connection allows.
class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  SyncService() {
    WidgetsBinding.instance.addObserver(this);
    ConnectivityService.instance.addListener(_trigger);
    OfflineStore.pending.addListener(_onPendingChanged);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _trigger());
    _trigger();
  }

  /// Called after at least one write reached the server, so screens reload.
  static VoidCallback? onSynced;

  Timer? _timer;
  bool _syncing = false;

  bool get syncing => _syncing;

  /// The signed-in person. Writes are shown, counted and sent only for them:
  /// one made by somebody else on this device waits for its owner.
  static String? get currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null; // Supabase not started (setup screen, tests)
    }
  }

  int get pendingCount {
    final me = currentUserId;
    return me == null ? 0 : OfflineStore.pendingCount(forUser: me);
  }

  int get failedCount {
    final me = currentUserId;
    return me == null ? 0 : OfflineStore.failedWrites(forUser: me).length;
  }

  void _onPendingChanged() {
    notifyListeners();
    _trigger();
  }

  void _trigger() {
    if (pendingCount > 0) flush();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _trigger();
  }

  /// Tries every waiting write, oldest first. A lost connection stops the run
  /// (the rest wait); a write the server refuses is set aside, not dropped.
  Future<void> flush() async {
    if (_syncing) return;
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final me = currentUserId;
    if (token == null || me == null) return;

    _syncing = true;
    notifyListeners();
    var sent = 0;
    try {
      for (final write in OfflineStore.pendingWrites(forUser: me)) {
        final request = http.Request(write.method, Uri.parse(write.url))
          ..headers.addAll(write.headers)
          ..headers['Authorization'] = 'Bearer $token'
          ..bodyBytes = base64Decode(write.bodyBase64);
        try {
          final response = await OfflineHttpClient.raw.send(request);
          final body = await response.stream.bytesToString();
          final code = response.statusCode;
          if (code >= 200 && code < 300) {
            await OfflineStore.removeWrite(write.id);
            sent++;
          } else if (code == 401 || code >= 500) {
            break; // sign-in expired or server trouble: try again later
          } else {
            await OfflineStore.markFailed(write, _reason(code, body));
          }
        } catch (e) {
          if (OfflineHttpClient.isNetworkError(e)) {
            ConnectivityService.instance.markOffline();
            break;
          }
          await OfflineStore.markFailed(write, '$e');
        }
      }
    } finally {
      _syncing = false;
      notifyListeners();
    }
    if (sent > 0) {
      ConnectivityService.instance.markOnline();
      onSynced?.call();
    }
  }

  String _reason(int code, String body) {
    try {
      final map = jsonDecode(body) as Map;
      return '$code ${map['message'] ?? map['error'] ?? ''}'.trim();
    } catch (_) {
      return '$code';
    }
  }

  Future<void> retryFailed(String id) async {
    await OfflineStore.retryFailed(id);
    notifyListeners();
  }

  Future<void> discardFailed(String id) async {
    await OfflineStore.discardFailed(id);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ConnectivityService.instance.removeListener(_trigger);
    OfflineStore.pending.removeListener(_onPendingChanged);
    super.dispose();
  }
}
