import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:web/web.dart' as web;

/// Picks photos with a plain `<input type="file">` and shrinks them **one at
/// a time** to at most [maxSide] pixels as JPEG.
///
/// image_picker's browser picker shrank every chosen photo at once; with
/// several full-size iPhone photos that ran the page out of memory and Safari
/// reloaded it. One photo in memory at a time avoids that. The input is
/// clicked inside the tap, because iOS only opens a picker for a direct user
/// gesture. [camera] asks for the camera instead of the library.
///
/// A photo the browser cannot decode (HEIC in Chrome, say) is kept as it is;
/// the upload then names it by its real content.
Future<List<XFile>> pickPhotosInBrowser({
  int maxSide = 1024,
  double quality = 0.85,
  bool camera = false,
}) {
  final completer = Completer<List<XFile>>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..multiple = !camera
    ..style.display = 'none';
  if (camera) input.setAttribute('capture', 'environment');
  web.document.body!.append(input);

  void finish(List<XFile> files) {
    input.remove();
    if (!completer.isCompleted) completer.complete(files);
  }

  Future<void> read() async {
    final files = input.files;
    if (files == null || files.length == 0) {
      finish(const []);
      return;
    }
    final out = <XFile>[];
    for (var i = 0; i < files.length; i++) {
      final file = files.item(i)!;
      out.add(await _shrink(file, maxSide, quality) ?? await _asIs(file));
    }
    finish(out);
  }

  input.addEventListener(
      'change',
      ((web.Event _) {
        unawaited(read());
      }).toJS);
  input.addEventListener(
      'cancel',
      ((web.Event _) {
        finish(const []);
      }).toJS);

  input.click();
  return completer.future;
}

Future<XFile> _asIs(web.File file) async {
  final buffer = await file.arrayBuffer().toDart;
  return XFile.fromData(
    buffer.toDart.asUint8List(),
    name: file.name,
    mimeType: file.type.isEmpty ? null : file.type,
  );
}

/// The photo drawn at most [maxSide] wide or high, as JPEG; null when the
/// browser cannot decode it.
Future<XFile?> _shrink(web.File file, int maxSide, double quality) async {
  web.ImageBitmap? bitmap;
  try {
    bitmap = await web.window.createImageBitmap(file).toDart;
    final scale = math.min(
      1.0,
      maxSide / math.max(bitmap.width, bitmap.height),
    );
    final w = math.max(1, (bitmap.width * scale).round());
    final h = math.max(1, (bitmap.height * scale).round());

    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    ctx.drawImage(bitmap, 0, 0, w, h);

    final done = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? blob) => done.complete(blob)).toJS,
      'image/jpeg',
      quality.toJS,
    );
    final blob = await done.future;
    // Let the canvas go at once: it is the big allocation.
    canvas
      ..width = 0
      ..height = 0;
    if (blob == null) return null;
    final bytes = (await blob.arrayBuffer().toDart).toDart.asUint8List();
    final base = file.name.contains('.')
        ? file.name.substring(0, file.name.lastIndexOf('.'))
        : file.name;
    return XFile.fromData(
      Uint8List.fromList(bytes),
      name: '$base.jpg',
      mimeType: 'image/jpeg',
    );
  } catch (_) {
    return null;
  } finally {
    bitmap?.close();
  }
}
