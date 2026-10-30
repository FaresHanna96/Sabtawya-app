import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';

/// The picture of a class patron saint, falling back to an icon.
///
/// The bucket is private, so the image comes through a signed URL that
/// [PhotoService] caches. Icons rather than initials are used for the
/// placeholder: an empty frame reads as "no picture yet" instead of as data.
class PatronAvatar extends StatefulWidget {
  const PatronAvatar({
    super.key,
    required this.photoPath,
    this.size = 56,
    this.localPreview,
  });

  final String? photoPath;
  final double size;

  /// Bytes of a just-picked picture, shown before it has been uploaded.
  final Uint8List? localPreview;

  @override
  State<PatronAvatar> createState() => _PatronAvatarState();
}

class _PatronAvatarState extends State<PatronAvatar> {
  Future<String?>? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PatronAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPath != widget.photoPath) _resolve();
  }

  void _resolve() {
    final path = widget.photoPath;
    _url = (path == null || path.isEmpty)
        ? Future<String?>.value(null)
        : PhotoService.signedUrl(bucket: Db.bucketClassPatrons, path: path);
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.localPreview;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: AppColors.maroon.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: preview != null
          ? Image.memory(
              preview,
              fit: BoxFit.cover,
              width: widget.size,
              height: widget.size,
            )
          : FutureBuilder<String?>(
              future: _url,
              builder: (context, snapshot) {
                final url = snapshot.data;
                if (url == null) return _placeholder();
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: widget.size,
                  height: widget.size,
                  errorBuilder: (_, __, ___) => _placeholder(),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : _placeholder(),
                );
              },
            ),
    );
  }

  Widget _placeholder() => Icon(
        Icons.church_outlined,
        size: widget.size * 0.5,
        color: AppColors.maroon,
      );
}
