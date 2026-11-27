import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/web_pwa_stub.dart'
    if (dart.library.js_interop) '../../core/services/web_pwa_web.dart';
import '../../core/theme/app_theme.dart';
import '../../state/session_controller.dart';

/// The website's screen lock: this device's passkey (fingerprint, Face ID or
/// the screen code) before the app shows. Off unless the servant turns it on.
///
/// It hides the screen from whoever picks the phone up; it does not encrypt
/// what the browser has saved.
class AppLockStore {
  const AppLockStore();

  static const _boxName = 'app_lock';
  static const _key = 'passkey';

  /// The passkey that opens the app, or null when the lock is off.
  Future<String?> passkey() async {
    try {
      final v = (await Hive.openBox<dynamic>(_boxName)).get(_key);
      return v is String && v.isNotEmpty ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String id) async =>
      (await Hive.openBox<dynamic>(_boxName)).put(_key, id);

  /// Turns the lock off (the switch, or signing out).
  Future<void> clear() async {
    try {
      await (await Hive.openBox<dynamic>(_boxName)).delete(_key);
    } catch (_) {}
  }
}

/// Covers [child] while the lock is on: when the app opens, and when it comes
/// back after [awayAllowed] out of sight. The pages underneath stay as they
/// were, unsaved marks included.
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
    this.web = kIsWeb,
    this.store = const AppLockStore(),
    this.check = checkPasskey,
    this.now = DateTime.now,
  });

  final Widget child;

  /// Tests replace the browser and the clock.
  final bool web;
  final AppLockStore store;
  final Future<bool> Function(String id) check;
  final DateTime Function() now;

  static const awayAllowed = Duration(minutes: 5);

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;

  /// Reading whether a lock is set: covered by the plain background meanwhile,
  /// so nothing shows early and no lock screen flashes where there is none.
  bool _reading = false;
  bool _checking = false;
  bool _failed = false;

  /// Whether the lock has been looked at for this run of the app. A person who
  /// signs in has just proved who they are, so only an app that opens already
  /// signed in starts locked.
  bool _opened = false;
  bool _sawSignedOut = false;
  DateTime? _hiddenAt;

  @override
  void initState() {
    super.initState();
    if (widget.web) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final left = _hiddenAt;
      _hiddenAt = null;
      if (left != null &&
          widget.now().difference(left) >= AppLockGate.awayAllowed) {
        _lockIfSet();
      }
    } else {
      _hiddenAt ??= widget.now();
    }
  }

  Future<void> _lockIfSet() async {
    final id = await widget.store.passkey();
    if (!mounted) return;
    setState(() {
      _reading = false;
      _locked = id != null;
      _failed = false;
    });
  }

  Future<void> _unlock() async {
    final id = await widget.store.passkey();
    if (id == null) {
      if (mounted) setState(() => _locked = false);
      return;
    }
    setState(() {
      _checking = true;
      _failed = false;
    });
    final ok = await widget.check(id);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _locked = !ok;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.web) return widget.child;
    final status = context.select<SessionController, SessionStatus>(
      (s) => s.status,
    );
    if (status == SessionStatus.signedOut) {
      _sawSignedOut = true;
      _locked = false;
    } else if (status == SessionStatus.ready && !_opened) {
      _opened = true;
      if (!_sawSignedOut) {
        _reading = true;
        _lockIfSet();
      }
    }
    final signedIn = status != SessionStatus.signedOut;
    final covered = signedIn && (_locked || _reading);
    return Stack(
      children: [
        ExcludeFocus(
          excluding: covered,
          child: ExcludeSemantics(excluding: covered, child: widget.child),
        ),
        if (covered && !_locked)
          const Positioned.fill(
            child: DecoratedBox(
              decoration:
                  BoxDecoration(gradient: AppGradients.loginBackground),
            ),
          ),
        if (covered && _locked)
          Positioned.fill(
            child: _LockScreen(
              busy: _checking,
              failed: _failed,
              onOpen: _unlock,
              onSignOut: () => context.read<SessionController>().signOut(),
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.busy,
    required this.failed,
    required this.onOpen,
    required this.onSignOut,
  });

  final bool busy;
  final bool failed;
  final VoidCallback onOpen;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        decoration: const BoxDecoration(gradient: AppGradients.loginBackground),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, size: 64, color: Colors.white),
                  const SizedBox(height: 20),
                  const Text(
                    AppStrings.appLockedTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (failed) ...[
                    const SizedBox(height: 12),
                    const Text(
                      AppStrings.appLockFailed,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: busy ? null : onOpen,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.navyDark,
                      minimumSize: const Size(220, 48),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text(AppStrings.appLockOpen),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onSignOut,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      minimumSize: const Size(220, 44),
                    ),
                    child: const Text(AppStrings.logout),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
