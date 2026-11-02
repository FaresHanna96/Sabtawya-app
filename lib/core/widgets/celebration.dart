import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A short confetti burst drawn over the whole screen.
///
/// Call [Celebration.show] after something worth cheering for, such as saving a
/// whole attendance sheet. It ignores touches, removes itself, and does nothing
/// when the device has animations turned off.
class Celebration {
  const Celebration._();

  static void show(BuildContext context) {
    if (!context.mounted) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: _ConfettiBurst(onDone: () => entry.remove()),
      ),
    );
    overlay.insert(entry);
  }
}

class _Piece {
  _Piece(math.Random r)
      : angle = (r.nextDouble() - 0.5) * math.pi * 1.1 - math.pi / 2,
        speed = 380 + r.nextDouble() * 520,
        spin = (r.nextDouble() - 0.5) * 12,
        size = 6 + r.nextDouble() * 7,
        color = _colors[r.nextInt(_colors.length)],
        round = r.nextBool();

  static const _colors = <Color>[
    AppColors.gold,
    AppColors.coral,
    AppColors.sky,
    AppColors.oliveLight,
    AppColors.navyLight,
    AppColors.maroon,
  ];

  final double angle;
  final double speed;
  final double spin;
  final double size;
  final Color color;
  final bool round;
}

class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  final _pieces = List.generate(70, (_) => _Piece(math.Random()));

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_pieces, _ctrl.value),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    final secs = t * 1.8;
    for (final p in pieces) {
      final dx = math.cos(p.angle) * p.speed * secs * 0.55;
      final dy = math.sin(p.angle) * p.speed * secs * 0.55 + 420 * secs * secs;
      final pos = origin + Offset(dx, dy);
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - t * t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * secs);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
