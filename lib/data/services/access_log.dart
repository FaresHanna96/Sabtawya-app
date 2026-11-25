import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_version.dart';

/// Records that the app was opened (kind + platform + time, nothing personal).
/// Fire and forget: a failure or no connection is ignored and never queued.
class AccessLog {
  const AccessLog._();

  static Future<void> appOpened() => _event(
        'app_open',
        kIsWeb ? 'web' : defaultTargetPlatform.name,
      );

  /// The platform an update downloaded from inside the app is logged under, so
  /// the stats page can tell it from a download off the download page.
  static const updatePlatform = 'update';

  static bool _updateLogged = false;

  /// Tests watch the event instead of sending it.
  @visibleForTesting
  static void Function()? debugOnUpdateDownload;

  /// The in-app updater began downloading the new version: counted as a
  /// download, once per run of the app (retries are the same person).
  static void updateDownloadStarted() {
    if (_updateLogged) return;
    _updateLogged = true;
    final hook = debugOnUpdateDownload;
    if (hook != null) {
      hook();
      return;
    }
    _event('apk_download', updatePlatform);
  }

  @visibleForTesting
  static void debugResetUpdateLogged() => _updateLogged = false;

  static Future<void> _event(String kind, String platform) async {
    try {
      await http
          .post(
            Uri.parse('${AppConfig.supabaseUrl}/rest/v1/access_events'),
            headers: {
              'apikey': AppConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
              'Content-Type': 'application/json',
              'Prefer': 'return=minimal',
            },
            body: '{"kind":"$kind","platform":"$platform"}',
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  /// Tells the database which build this signed-in user runs (see
  /// user_app_builds). Quietly does nothing when signed out or offline.
  static Future<void> recordBuild() async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return;
      await client.rpc('record_app_build', params: {
        'p_build': kAppBuild,
        'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      }).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}
