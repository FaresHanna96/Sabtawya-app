import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// One place for the app's haptic feedback, so every screen feels the same.
///
/// Does nothing on the web, and never throws: a device without a vibration
/// motor simply ignores the call.
class Haptics {
  const Haptics._();

  /// A light tap: pressing a button.
  static void tap() => _run(HapticFeedback.lightImpact);

  /// A tick: changing a tab, a filter or a toggle.
  static void select() => _run(HapticFeedback.selectionClick);

  /// Something was saved.
  static void success() => _run(HapticFeedback.mediumImpact);

  /// Something failed or is about to be destroyed.
  static void warn() => _run(HapticFeedback.heavyImpact);

  static void _run(Future<void> Function() f) {
    if (kIsWeb) return;
    try {
      f();
    } catch (_) {}
  }
}
