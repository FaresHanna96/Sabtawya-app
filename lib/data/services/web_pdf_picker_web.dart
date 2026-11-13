import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:web/web.dart' as web;

/// Picks one PDF with a plain `<input type="file">`, the same way the photo
/// picker does, which is what works on Safari for iPhone (file_picker's web
/// input made that page reload). The input is clicked synchronously, inside the
/// tap, because iOS only opens the picker for a direct user gesture.
Future<XFile?> pickPdfInBrowser() {
  final completer = Completer<XFile?>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'application/pdf,.pdf'
    ..style.display = 'none';
  web.document.body!.append(input);

  void finish(XFile? file, [Object? error]) {
    input.remove();
    if (completer.isCompleted) return;
    if (error != null) {
      completer.completeError(error);
    } else {
      completer.complete(file);
    }
  }

  Future<void> read() async {
    final files = input.files;
    if (files == null || files.length == 0) {
      finish(null);
      return;
    }
    final picked = files.item(0)!;
    try {
      final buffer = await picked.arrayBuffer().toDart;
      final Uint8List bytes = buffer.toDart.asUint8List();
      finish(XFile.fromData(
        bytes,
        name: picked.name,
        mimeType: 'application/pdf',
      ));
    } catch (e) {
      finish(null, e);
    }
  }

  // The JS callbacks must be plain void functions; the reading is async.
  input.addEventListener(
      'change',
      ((web.Event _) {
        unawaited(read());
      }).toJS);
  input.addEventListener(
      'cancel',
      ((web.Event _) {
        finish(null);
      }).toJS);

  input.click();
  return completer.future;
}
