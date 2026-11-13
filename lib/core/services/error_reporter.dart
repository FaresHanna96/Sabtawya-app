import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';
import '../config/app_version.dart';

/// Sends errors the app did not handle somewhere they can be seen.
///
/// Android: Firebase Crashlytics (the push project). Web: Crashlytics does
/// not run there, so the error goes to the app_errors table, which admins
/// read on the stats page. No names, emails or children's data are sent:
/// only the error, where it happened and the app version.
class ErrorReporter {
  const ErrorReporter._();

  static bool _ready = false;

  static Future<void> init() async {
    if (kDebugMode) return; // a developer sees errors in the console
    try {
      if (!kIsWeb) {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.current);
        }
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(true);
        await FirebaseCrashlytics.instance
            .setCustomKey('app_version', '$kAppVersion+$kAppBuild');
      }
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        previous?.call(details);
        report(details.exception, details.stack, fatal: false);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        report(error, stack, fatal: true);
        return true;
      };
      _ready = true;
    } catch (_) {
      // Reporting must never stop the app from starting.
    }
  }

  static void report(Object error, StackTrace? stack, {bool fatal = false}) {
    if (!_ready) return;
    if (!kIsWeb) {
      unawaited(FirebaseCrashlytics.instance
          .recordError(error, stack, fatal: fatal)
          .catchError((Object _) {}));
      return;
    }
    // Web: one row, best effort, and only for someone signed in.
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      unawaited(client.from('app_errors').insert(<String, dynamic>{
        'message': error.toString().substring(
            0, error.toString().length.clamp(0, 500)),
        'stack': (stack?.toString() ?? '')
            .substring(0, (stack?.toString() ?? '').length.clamp(0, 2000)),
        'platform': 'web',
        'app_version': '$kAppVersion+$kAppBuild',
      }).then((_) {}, onError: (Object _) {}));
    } catch (_) {}
  }
}
