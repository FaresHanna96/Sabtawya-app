import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/utils/contact_entries.dart';
import '../repositories/child_repository.dart';
import '../repositories/class_repository.dart';

/// "Show caller name": a call from a saved family shows who it is, even when
/// the servant never saved the number. The phone does the showing (an
/// Android notification, an iPhone call-directory label); this hands it the
/// numbers of the servant's own children and families.
///
/// The numbers stay on the phone, are sent nowhere, and are removed when the
/// feature is switched off or the servant signs out.
class CallerIdService {
  const CallerIdService._();

  static const _channel = MethodChannel('sabtawya/caller_id');

  /// Only the phone apps can do it, never the website.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// On and allowed by the phone.
  static Future<bool> isEnabled() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the phone's permission, then saves the numbers. False when the
  /// servant said no (or the phone cannot do it).
  static Future<bool> enable() async {
    if (!supported) return false;
    try {
      final allowed =
          await _channel.invokeMethod<bool>('requestPermissions') ?? false;
      // iPhone has no prompt: the servant switches the extension on in
      // Settings, so the numbers are saved first and work from then on.
      if (allowed || defaultTargetPlatform == TargetPlatform.iOS) {
        await _push();
      }
      return allowed;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disable() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } catch (_) {}
  }

  /// Brings the saved numbers up to date (children added or numbers changed);
  /// only when the feature is on. Quiet on any failure: offline is fine, the
  /// old list stays.
  static Future<void> refresh() async {
    if (!await isEnabled()) return;
    try {
      await _push();
    } catch (_) {}
  }

  static Future<void> _push() async {
    final (children, classes) =
        await (const ChildRepository().all(), const ClassRepository().list())
            .wait;
    final entries = contactEntriesFor(
      children,
      {for (final c in classes) c.id: c.name},
    );
    await _channel.invokeMethod<void>('setNumbers', <String, String>{
      for (final e in entries) e.number.replaceAll('+', ''): e.label,
    });
  }
}
