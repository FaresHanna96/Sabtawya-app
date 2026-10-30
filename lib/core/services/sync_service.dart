import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/supabase/db.dart';
import 'connectivity_service.dart';
import 'offline_store.dart';

class SyncService extends ChangeNotifier {
  SyncService() {
    ConnectivityService.instance.addListener(_onConnectivityChanged);
    if (ConnectivityService.instance.isOnline && OfflineStore.pendingCount() > 0) {
      flush();
    }
  }

  bool _syncing = false;
  bool get syncing => _syncing;
  int get pendingCount => OfflineStore.pendingCount();

  void _onConnectivityChanged() {
    if (ConnectivityService.instance.isOnline && pendingCount > 0) {
      flush();
    }
    notifyListeners();
  }

  /// Replays queued writes in chronological order. Stops on network error and
  /// retries on the next reconnect. Permanent Supabase errors are discarded.
  Future<void> flush() async {
    if (_syncing || !ConnectivityService.instance.isOnline) return;
    _syncing = true;
    notifyListeners();

    try {
      for (final QueuedWrite write in OfflineStore.getPendingWrites()) {
        try {
          await Db.client
              .from(Db.tAttendanceRecords)
              .upsert(write.entries, onConflict: 'session_id,child_id');
          await OfflineStore.removeWrite(write.id);
          notifyListeners();
        } on PostgrestException catch (_) {
          await OfflineStore.removeWrite(write.id);
          notifyListeners();
        } catch (_) {
          break;
        }
      }
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
