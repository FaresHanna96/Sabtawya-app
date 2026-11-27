import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../data/supabase/db.dart';
import '../../firebase_options.dart';
import 'error_reporter.dart';
import 'push_tap.dart';
import 'web_taps_stub.dart' if (dart.library.js_interop) 'web_taps_web.dart';

export 'push_tap.dart';

/// Where the browser stands on notifications. [unknown] until asked about, and
/// for a browser that has none.
enum PushPermission { unknown, notAsked, granted, denied }

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

  /// The website's notification permission, for its card and settings row.
  final ValueNotifier<PushPermission> permission =
      ValueNotifier<PushPermission>(PushPermission.unknown);

  static const _fidWait = Duration(seconds: 10);

  bool _tapsListening = false;
  bool _webTapsListening = false;

  bool _listening = false;
  bool _tokenListening = false;
  bool _legacyHandled = false;
  String? _fid;
  Completer<String>? _waiting;

  /// The id or token last sent to the server for this device, to delete there
  /// at sign-out.
  String? _saved;

  static const _forgetWait = Duration(seconds: 5);

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

  /// The person tapped «فعّل الإشعارات»: asks the browser, then registers.
  Future<void> enableFromTap() => registerDevice(fromTap: true);

  static PushPermission _permissionOf(AuthorizationStatus status) =>
      switch (status) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional =>
          PushPermission.granted,
        AuthorizationStatus.denied => PushPermission.denied,
        _ => PushPermission.notAsked,
      };

  /// Registers this device for the signed-in user. Safe to call after every
  /// sign-in: the ID is re-attached to whoever is using the device now.
  ///
  /// A browser only lets a tap ask for permission (an iPhone ignores anything
  /// else), so on the website it is asked [fromTap] only; the phone app asks
  /// by itself.
  Future<void> registerDevice({bool fromTap = false}) async {
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
      var settings = kIsWeb && !fromTap
          ? await messaging.getNotificationSettings()
          : await messaging.requestPermission();
      permission.value = _permissionOf(settings.authorizationStatus);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (kIsWeb && permission.value != PushPermission.granted) return;

      if (!_listening) {
        _listening = true;
        messaging.onRegistered.listen(_onRegistered);
        FirebaseMessaging.onMessage.listen((_) => received.value++);
      }

      final waiting = _waiting = Completer<String>();
      String id = '';
      try {
        // Timed too: a call that never returns would also block the fallback.
        await messaging
            .register(
              vapidKey: kIsWeb ? DefaultFirebaseOptions.webVapidKey : null,
            )
            .timeout(_fidWait);
        id = await waiting.future.timeout(_fidWait, onTimeout: () => '');
      } catch (e, stack) {
        debugPrint('push: installation registration failed: $e');
        _report('register', e, stack);
      }
      if (id.isEmpty) await _registerWithToken(messaging);
    } catch (e) {
      // Push is a convenience; the app works without it.
      debugPrint('push registration skipped: $e');
    }
  }

  /// Why a browser could not register, on the stats page: it happens on
  /// people's own phones, where nobody can read the console.
  void _report(String step, Object error, StackTrace stack) {
    if (kIsWeb) ErrorReporter.report('push $step: $error', stack);
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
      final token = await messaging
          // ignore: deprecated_member_use
          .getToken(
            vapidKey: kIsWeb ? DefaultFirebaseOptions.webVapidKey : null,
          )
          .timeout(_fidWait);
      if (token != null) await _save(token);
      if (!_tokenListening) {
        _tokenListening = true;
        // ignore: deprecated_member_use
        messaging.onTokenRefresh.listen((t) => _save(t));
      }
    } catch (e, stack) {
      debugPrint('push: token registration skipped: $e');
      _report('token', e, stack);
    }
  }

  /// Stops pushes to this device for the person leaving it: deletes its row on
  /// the server (with [server], while there is still a session) and tells
  /// Firebase to stop delivering. Offline only the second can work; the server
  /// then drops the dead row at its next send. Never throws, never waits long.
  Future<void> forgetDevice({bool server = true}) async {
    final saved = _saved;
    _saved = null;
    if (server && saved != null) {
      await _forgetStep(
        () => Db.from('device_tokens').delete().eq('token', saved),
      );
    }
    if (Firebase.apps.isEmpty) return;
    await _forgetStep(() => FirebaseMessaging.instance.unregister());
    if (saved != null && !isInstallationId(saved)) {
      // ignore: deprecated_member_use
      await _forgetStep(() => FirebaseMessaging.instance.deleteToken());
    }
  }

  Future<void> _forgetStep(Future<void> Function() step) async {
    try {
      await step().timeout(_forgetWait);
    } catch (e) {
      debugPrint('push: forgetting this device: $e');
    }
  }

  Future<void> _save(String token, {String? replaces}) async {
    if (Db.client.auth.currentUser == null) return;
    // Remembered even if the save fails: the row may be there from before.
    _saved = token;
    try {
      await Db.client.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        if (replaces != null) 'p_replaces': replaces,
      });
    } catch (e, stack) {
      debugPrint('push: saving the device failed: $e');
      _report('save', e, stack);
    }
  }
}
