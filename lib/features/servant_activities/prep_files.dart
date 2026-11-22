import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../core/utils/file_kind.dart';

/// A file chosen for a lesson prep, not uploaded yet: its bytes (for the
/// preview and the size) and what it really is.
class PickedPrepFile {
  PickedPrepFile(this.file, this.bytes) : kind = FileKind.of(bytes);

  final XFile file;
  final Uint8List bytes;
  final FileKind kind;

  /// A PDF, whatever picker it came from or whatever it is called.
  bool get isPdf => kind.isPdf || FileKind.isPdfPath(file.name);
  int get size => bytes.length;
}

/// "3 صور + ملف PDF · 2.1 ميجا".
String pickedSummary(List<PickedPrepFile> files) {
  final photos = files.where((f) => !f.isPdf).length;
  final pdfs = files.length - photos;
  final parts = [
    if (photos == 1) 'صورة',
    if (photos == 2) 'صورتان',
    if (photos > 2) '$photos صور',
    if (pdfs == 1) 'ملف PDF',
    if (pdfs > 1) '$pdfs ملفات PDF',
  ];
  final total = files.fold<int>(0, (s, f) => s + f.size);
  return '${parts.join(' + ')} · ${sizeLabel(total)}';
}

/// "2.1 ميجا" / "350 ك.ب".
String sizeLabel(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميجا';
  }
  return '${math.max(1, (bytes / 1024).round())} ك.ب';
}

/// What an upload run left: the stored paths, and the files that failed
/// (kept so the servant can try them again).
class PrepUploadResult {
  const PrepUploadResult(this.paths, this.failed);

  final List<String> paths;
  final List<PickedPrepFile> failed;
}

/// Uploads [files] a few at a time ([parallel]), reporting each one done
/// through [onProgress]. One file failing never stops the others.
Future<PrepUploadResult> uploadPrepFiles({
  required List<PickedPrepFile> files,
  required Future<String> Function(PickedPrepFile file) upload,
  void Function(int done, int total)? onProgress,
  int parallel = 3,
}) async {
  final paths = List<String?>.filled(files.length, null);
  final failed = <PickedPrepFile>[];
  var next = 0;
  var done = 0;

  Future<void> worker() async {
    while (next < files.length) {
      final i = next++;
      try {
        paths[i] = await upload(files[i]);
      } catch (_) {
        failed.add(files[i]);
      }
      done++;
      onProgress?.call(done, files.length);
    }
  }

  await Future.wait([
    for (var w = 0; w < math.min(parallel, files.length); w++) worker(),
  ]);
  // Kept in the order they were picked.
  return PrepUploadResult(
    [for (final p in paths) if (p != null) p],
    [for (final f in files) if (failed.contains(f)) f],
  );
}
