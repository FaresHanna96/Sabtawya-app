import '../../core/services/app_badge_stub.dart'
    if (dart.library.js_interop) '../../core/services/app_badge_web.dart';
import '../../core/services/offline_store.dart';
import '../../core/services/push_service.dart';
import 'caller_id_service.dart';

/// What this device holds for the person signed in, and how to take it back
/// when their access ends: signed out, session expired or revoked, account
/// deactivated, refused or deleted.
///
/// Offline writes still waiting and unsaved attendance are not touched.
class DeviceCleanup {
  const DeviceCleanup();

  /// The unread count on the icon and the names shown for incoming calls.
  Future<void> hideNames() async {
    setAppBadge(0);
    await CallerIdService.disable();
  }

  /// [hideNames] and every kept copy of the server's answers.
  Future<void> wipe() async {
    try {
      await hideNames();
    } finally {
      await OfflineStore.clearCache();
    }
  }

  /// Stops pushes to this device. [server] false when there is no session left
  /// to delete the saved device with.
  Future<void> forgetPush({required bool server}) =>
      PushService.instance.forgetDevice(server: server);

  Future<void> registerPush() => PushService.instance.registerDevice();
}
