import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/offline_store.dart';

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
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const SabtawyaApp());
}
