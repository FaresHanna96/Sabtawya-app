import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/child.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';

/// A child's photo, falling back to a gender-tinted icon.
///
/// The bucket is private, so the image is loaded through a signed URL that
/// [PhotoService] caches; a child with no photo, or one the caller may not
/// read, simply shows the placeholder.
class ChildAvatar extends StatefulWidget {
  const ChildAvatar({
    super.key,
    required this.child,
    this.size = 44,
    this.localPreview,
  });

  final Child child;
  final double size;

  /// Bytes of a just-picked photo, shown before it has been uploaded.
  final Uint8List? localPreview;

  @override
  State<ChildAvatar> createState() => _ChildAvatarState();
}

class _ChildAvatarState extends State<ChildAvatar> {
  Future<String?>? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ChildAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.photoPath != widget.child.photoPath) _resolve();
  }

  void _resolve() {
    _url = widget.child.hasPhoto
        ? PhotoService.signedUrl(
            bucket: Db.bucketChildPhotos,
            path: widget.child.photoPath,
          )
        : Future<String?>.value(null);
  }

  Color get _tint =>
      widget.child.gender == Gender.boy ? AppColors.navyLight : AppColors.olive;

  @override
  Widget build(BuildContext context) {
    final preview = widget.localPreview;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: _tint.withValues(alpha: 0.12),
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
        widget.child.gender == Gender.boy ? Icons.boy : Icons.girl,
        size: widget.size * 0.56,
        color: _tint,
      );
}
