import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/offline_http_client.dart';
import 'core/services/offline_store.dart';
import 'data/services/access_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await OfflineStore.init();
  await ConnectivityService.instance.init();

  if (!AppConfig.isConfigured) {
    // Starting Supabase with empty credentials throws, so the app shows setup
    // instructions instead of crashing on launch.
    runApp(const SabtawyaSetupApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    httpClient: OfflineHttpClient(),
    // Offline handling lives in OfflineHttpClient; retries would only delay it.
    postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  AccessLog.appOpened();
  runApp(const SabtawyaApp());
}
