import 'package:cross_file/cross_file.dart';

/// Only used in the browser; the app picks photos through image_picker.
Future<List<XFile>> pickPhotosInBrowser({
  int maxSide = 1024,
  double quality = 0.85,
  bool camera = false,
}) async =>
    const <XFile>[];
