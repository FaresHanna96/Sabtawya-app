import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// An iPhone or iPad. A newer iPad calls itself a Mac, but a Mac has no touch
/// screen.
bool get isIosBrowser {
  final navigator = web.window.navigator;
  final agent = navigator.userAgent;
  if (RegExp('iPhone|iPad|iPod').hasMatch(agent)) return true;
  return agent.contains('Macintosh') && navigator.maxTouchPoints > 1;
}

/// Opened from its home-screen icon, not in a browser tab.
bool get isInstalledWebApp {
  try {
    if (web.window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
    // Safari's own flag, older than the standard above.
    final flag = (web.window.navigator as JSObject)['standalone'];
    return flag != null && flag.isA<JSBoolean>() && (flag as JSBoolean).toDart;
  } catch (_) {
    return false;
  }
}
