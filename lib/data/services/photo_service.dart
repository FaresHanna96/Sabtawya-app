import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/app_failure.dart';
import '../supabase/db.dart';

/// Photos stored in a private bucket: children, and class patron saints.
///
/// Only the object path is kept on the row. Display goes through a short-lived
/// signed URL, so the storage policies decide who can see a photo exactly as
/// they decide who can see the record it belongs to.
class PhotoService {
  const PhotoService._();

  /// Signed URLs last an hour; they are reused for slightly less than that so
  /// scrolling a long list does not re-sign the same image on every rebuild.
  static const _urlTtl = Duration(hours: 1);
  static const _cacheFor = Duration(minutes: 50);

  static final Map<String, _SignedUrl> _cache = <String, _SignedUrl>{};

  static final ImagePicker _picker = ImagePicker();

  /// Picks and downsizes an image. Returns null when the user cancels.
  static Future<XFile?> pick({required bool fromCamera}) async {
    try {
      return await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Picks multiple images from the gallery. Returns an empty list on cancel.
  static Future<List<XFile>> pickMultiple() async {
    try {
      return await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Uploads [file] under [ownerId] in [bucket] and returns the object path.
  ///
  /// The owner id is the first path segment, which is what the storage policies
  /// read, and the name carries a timestamp so a replacement never collides
  /// with a cached signed URL of the previous photo.
  static Future<String> upload({
    required String bucket,
    required String ownerId,
    required XFile file,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final extension = _extensionOf(file.name);
      final path =
          '$ownerId/${DateTime.now().millisecondsSinceEpoch}.$extension';

      await Db.client.storage.from(bucket).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: _mimeOf(extension)),
          );
      return path;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  static Future<void> remove({
    required String bucket,
    required String? path,
  }) async {
    if (path == null || path.isEmpty) return;
    try {
      _cache.remove(_key(bucket, path));
      await Db.client.storage.from(bucket).remove(<String>[path]);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// A signed URL for [path], or null when the object is gone or unreadable.
  ///
  /// A missing photo is not worth an error dialog, so failures resolve to null
  /// and the caller falls back to the placeholder avatar.
  static Future<String?> signedUrl({
    required String bucket,
    required String? path,
  }) async {
    if (path == null || path.isEmpty) return null;

    final key = _key(bucket, path);
    final cached = _cache[key];
    if (cached != null && cached.isFresh) return cached.url;

    try {
      final url = await Db.client.storage
          .from(bucket)
          .createSignedUrl(path, _urlTtl.inSeconds);
      _cache[key] = _SignedUrl(url: url, createdAt: DateTime.now());
      return url;
    } catch (_) {
      return null;
    }
  }

  /// Drops a cached URL, used after a photo is replaced or removed.
  static void forget({required String bucket, required String? path}) {
    if (path == null) return;
    _cache.remove(_key(bucket, path));
  }

  static String _key(String bucket, String path) => '$bucket/$path';

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'jpg';
    final extension = name.substring(dot + 1).toLowerCase();
    return const <String>{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? extension
        : 'jpg';
  }

  static String _mimeOf(String extension) => switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}

class _SignedUrl {
  const _SignedUrl({required this.url, required this.createdAt});

  final String url;
  final DateTime createdAt;

  bool get isFresh =>
      DateTime.now().difference(createdAt) < PhotoService._cacheFor;
}
