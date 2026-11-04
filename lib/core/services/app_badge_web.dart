import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Puts the unread count on the app icon when the site is added to the home
/// screen (iPhone 16.4+ and Chrome/Edge installed apps). Browsers without the
/// Badging API simply ignore the call.
void setAppBadge(int count) {
  try {
    final nav = web.window.navigator as JSObject;
    final method = count > 0 ? 'setAppBadge' : 'clearAppBadge';
    if (!nav.has(method)) return;
    final result = count > 0
        ? nav.callMethod<JSAny?>(method.toJS, count.toJS)
        : nav.callMethod<JSAny?>(method.toJS);
    if (result != null && result.isA<JSPromise>()) {
      unawaited((result as JSPromise).toDart.then((_) {}, onError: (_) {}));
    }
  } catch (_) {
    // A badge is a nicety; never let it break the app.
  }
}
