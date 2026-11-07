import 'package:flutter/material.dart';

/// Opens [url] full screen on a dark background. Pinch to zoom, drag to move
/// around, double-tap to zoom in and out, tap the X (or swipe back) to close.
Future<void> showZoomableImage(BuildContext context, String url) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ImageViewer(url: url),
    ),
  );
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.url});

  final String url;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  final _controller = TransformationController();
  Offset _doubleTapAt = Offset.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final zoomedIn = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (zoomedIn) {
      _controller.value = Matrix4.identity();
      return;
    }
    const scale = 3.0;
    final p = _doubleTapAt;
    // Zoom towards the tapped point.
    _controller.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(-p.dx * (scale - 1), -p.dy * (scale - 1), 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // `expand` matters: without it the Stack shrinks to its only
      // non-positioned child (the close button) and the picture is squeezed
      // into that tiny box in the corner.
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1,
                maxScale: 8,
                // Fill the screen and let `contain` fit the picture inside it:
                // without a fixed size the picture is laid out at its own
                // pixel size, which showed as a tiny image in the corner.
                child: SizedBox.expand(
                  child: Image.network(
                    widget.url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Pinned to the corner: inside an expanding Stack a bare child
          // would stretch to the whole screen and close the viewer on any tap.
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
