import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../data/supabase/db.dart';
import '../../firebase_options.dart';
import 'push_tap.dart';
import 'web_taps_stub.dart' if (dart.library.js_interop) 'web_taps_web.dart';

export 'push_tap.dart';

/// Push notifications: registers this device so the edge functions can reach
/// it (a join request for admins, a decision or any bell entry for servants).
///
/// A device is identified by its Firebase installation ID (`register()` and
/// `onRegistered`), which replaces the registration token that
/// `getToken()` / `onTokenRefresh` handed out. Moving over safely:
///
/// * An installation ID that does not arrive in [_fidWait] (an older Google
///   Play services, a blocked network) falls back to the token, so the device
///   keeps getting pushes.
/// * Phones that registered a token with an earlier version still have that
///   row. Once the new ID is saved, the token is read one last time and sent
///   along so the server deletes that row, otherwise the phone would be
///   addressed twice and show every push twice.
///
/// The two `getToken` / `onTokenRefresh` uses below are the only ones left;
/// when firebase_messaging removes them, delete [_legacyToken] and
/// [_registerWithToken] (the fallback) and the `replaces` argument.
class PushService {
  PushService._();
  static final instance = PushService._();

  /// Bumped when a push arrives while the app is open, so the bell can refresh.
  final ValueNotifier<int> received = ValueNotifier<int>(0);

  /// A notification the person tapped and the app has not opened yet. The
  /// home shell takes it once someone is signed in.
  final ValueNotifier<PushTap?> tapped = ValueNotifier<PushTap?>(null);

  static const _fidWait = Duration(seconds: 10);

  bool _tapsListening = false;
  bool _webTapsListening = false;

  bool _listening = false;
  bool _tokenListening = false;
  bool _legacyHandled = false;
  String? _fid;
  Completer<String>? _waiting;

  /// An installation ID: 22 characters of base64url. A registration token is
  /// far longer and has a colon in it. The edge functions use the same rule to
  /// pick the field to send to.
  @visibleForTesting
  static bool isInstallationId(String id) =>
      RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(id);

  /// Hears taps on the website's notifications. Called once at startup, while
  /// the address the app was opened at is still untouched.
  void listenForTaps() {
    if (_webTapsListening) return;
    _webTapsListening = true;
    listenForWebTaps((data) => _onTap(PushTap.fromData(data)));
  }

  void _onTap(PushTap? tap) {
    if (tap != null) tapped.value = tap;
  }

  void _onOpened(RemoteMessage message) => _onTap(PushTap.fromData(
        message.data,
        title: message.notification?.title,
        body: message.notification?.body,
      ));

  /// Registers this device for the signed-in user. Safe to call after every
  /// sign-in: the ID is re-attached to whoever is using the device now.
  Future<void> registerDevice() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.current);
      }
      final messaging = FirebaseMessaging.instance;
      if (!kIsWeb && !_tapsListening) {
        _tapsListening = true;
        // Tapped while the app was in the background, or closed.
        FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
        unawaited(messaging.getInitialMessage().then((m) {
          if (m != null) _onOpened(m);
        }));
      }
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      if (!_listening) {
        _listening = true;
        messaging.onRegistered.listen(_onRegistered);
        FirebaseMessaging.onMessage.listen((_) => received.value++);
      }

      final waiting = _waiting = Completer<String>();
      String id = '';
      try {
        await messaging.register(
          vapidKey: kIsWeb ? DefaultFirebaseOptions.webVapidKey : null,
        );
        id = await waiting.future.timeout(_fidWait, onTimeout: () => '');
      } catch (e) {
        debugPrint('push: installation registration failed: $e');
      }
      if (id.isEmpty) await _registerWithToken(messaging);
    } catch (e) {
      // Push is a convenience; the app works without it.
      debugPrint('push registration skipped: $e');
    }
  }

  void _onRegistered(String id) {
    final waiting = _waiting;
    if (waiting != null && !waiting.isCompleted) waiting.complete(id);
    final previous = _fid;
    _fid = id;
    unawaited(() async {
      // A changed ID replaces the one saved before; the first one this run
      // replaces the registration token of an earlier app version, if any.
      final replaces = previous ?? await _legacyToken();
      await _save(id, replaces: replaces == id ? null : replaces);
    }());
  }

  /// The token an earlier version registered, read one last time so the server
  /// can drop that row. Null when there is none or it cannot be read.
  Future<String?> _legacyToken() async {
    if (_legacyHandled) return null;
    _legacyHandled = true;
    try {
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? DefaultFirebaseOptions.webVapidKey : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// The fallback: the old way, used only when no installation ID arrives.
  Future<void> _registerWithToken(FirebaseMessaging messaging) async {
    try {
      // ignore: deprecated_member_use
      final token = await messaging.getToken(
        vapidKey: kIsWeb ? DefaultFirebaseOptions.webVapidKey : null,
      );
      if (token != null) await _save(token);
      if (!_tokenListening) {
        _tokenListening = true;
        // ignore: deprecated_member_use
        messaging.onTokenRefresh.listen((t) => _save(t));
      }
    } catch (e) {
      debugPrint('push: token registration skipped: $e');
    }
  }

  Future<void> _save(String token, {String? replaces}) async {
    if (Db.client.auth.currentUser == null) return;
    try {
      await Db.client.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        if (replaces != null) 'p_replaces': replaces,
      });
    } catch (e) {
      debugPrint('push: saving the device failed: $e');
    }
  }
}
