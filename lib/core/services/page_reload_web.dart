import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Loads the newest version of the site. The service worker is asked to fetch
/// the new files first, so the reload is not served from its old copy
/// (index.html makes a waiting worker take over at once).
Future<void> reloadPage() async {
  try {
    final reg =
        await web.window.navigator.serviceWorker.getRegistration().toDart;
    if (reg != null) {
      await reg.update().toDart.timeout(const Duration(seconds: 4));
    }
  } catch (_) {
    // No worker, or it is slow: a plain reload still gets the new files.
  }
  web.window.location.reload();
}
