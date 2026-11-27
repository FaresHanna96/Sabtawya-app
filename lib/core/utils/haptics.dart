import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../services/web_pwa_stub.dart'
    if (dart.library.js_interop) '../services/web_pwa_web.dart';

/// One place for the app's haptic feedback, so every screen feels the same.
///
/// Never throws: a device (or a browser, as on iPhone) without vibration
/// simply ignores the call.
class Haptics {
  const Haptics._();

  /// A light tap: pressing a button.
  static void tap() => _run(HapticFeedback.lightImpact, 10);

  /// A tick: changing a tab, a filter or a toggle.
  static void select() => _run(HapticFeedback.selectionClick, 8);

  /// Something was saved.
  static void success() => _run(HapticFeedback.mediumImpact, 20);

  /// Something failed or is about to be destroyed.
  static void warn() => _run(HapticFeedback.heavyImpact, 40);

  static void _run(Future<void> Function() f, int milliseconds) {
    try {
      kIsWeb ? vibrate(milliseconds) : f();
    } catch (_) {}
  }
}
