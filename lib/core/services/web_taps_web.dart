import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// A tapped browser notification reaches the page in one of two ways (see
/// web/firebase-messaging-sw.js): a closed app is opened at `/?n=<id>`, an
/// open one is sent a message.
void listenForWebTaps(void Function(Map<String, dynamic> data) onTap) {
  final id = Uri.base.queryParameters['n'];
  if (id != null && id.isNotEmpty) {
    onTap({'notification_id': id});
    // A reload must not open it again.
    final clean = Uri.base.replace(queryParameters: const {}).toString();
    web.window.history.replaceState(
      null,
      '',
      clean.replaceFirst('?#', '#').replaceFirst(RegExp(r'\?$'), ''),
    );
  }
  try {
    web.window.navigator.serviceWorker.addEventListener(
      'message',
      ((web.MessageEvent event) {
        final message = event.data.dartify();
        if (message is! Map) return;
        final tap = message['sabtawyaTap'];
        if (tap is Map) {
          onTap({for (final e in tap.entries) '${e.key}': e.value});
        }
      }).toJS,
    );
    web.window.navigator.serviceWorker.startMessages();
  } catch (_) {
    // No service worker here: only the address can carry a tap.
  }
}
