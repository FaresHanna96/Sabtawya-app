import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../data/supabase/db.dart';
import '../../firebase_options.dart';

/// Push notifications for the admin: registers this device's FCM token so the
/// `push-admins` edge function can reach it when a join request arrives.
class PushService {
  PushService._();
  static final instance = PushService._();

  /// Bumped when a push arrives while the app is open, so the bell can refresh.
  final ValueNotifier<int> received = ValueNotifier<int>(0);

  bool _listening = false;

  /// Registers this device for the signed-in user. Safe to call after every
  /// sign-in: the token is re-attached to whoever is using the device now.
  Future<void> registerDevice() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.current);
      }
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken(
        vapidKey: kIsWeb ? DefaultFirebaseOptions.webVapidKey : null,
      );
      if (token != null) await _save(token);

      if (!_listening) {
        _listening = true;
        messaging.onTokenRefresh.listen(_save);
        FirebaseMessaging.onMessage.listen((_) => received.value++);
      }
    } catch (e) {
      // Push is a convenience; the app works without it.
      debugPrint('push registration skipped: $e');
    }
  }

  Future<void> _save(String token) async {
    if (Db.client.auth.currentUser == null) return;
    await Db.client.rpc('register_device_token', params: {
      'p_token': token,
      'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });
  }
}
