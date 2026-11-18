import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_version.dart';

/// Records that the app was opened (kind + platform + time, nothing personal).
/// Fire and forget: a failure or no connection is ignored and never queued.
class AccessLog {
  const AccessLog._();

  static Future<void> appOpened() async {
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
            body:
                '{"kind":"app_open","platform":"${kIsWeb ? 'web' : defaultTargetPlatform.name}"}',
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
