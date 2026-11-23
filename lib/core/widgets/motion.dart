import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;

import '../utils/haptics.dart';

bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Fades and slides its child up on first build. Give list items their index so
/// they arrive one after another; the delay is capped so long lists stay snappy.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 18,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final int index;
  final double offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final delay = Duration(milliseconds: 60 * index.clamp(0, 8));
    final total = duration + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * offset),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Scales its child down slightly while pressed, for tactile tap feedback.
class Bounce extends StatefulWidget {
  const Bounce({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Bounce> createState() => _BounceState();
}

class _BounceState extends State<Bounce> {
  bool _down = false;
  Offset? _start;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    // The press is read from the raw pointer, not from a tap recognizer: the
    // child is usually an InkWell with its own tap, which won the gesture and
    // left the scale unseen on a quick tap. A drag (scrolling) lets go.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _start = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        final start = _start;
        if (start != null && (e.position - start).distance > kTouchSlop) {
          _set(false);
        }
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap == null
            ? null
            : () {
                Haptics.tap();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Gently loops between two scales; used for badges and hero icons.
class Pulse extends StatefulWidget {
  const Pulse({
    super.key,
    required this.child,
    this.minScale = 0.94,
    this.maxScale = 1.06,
    this.duration = const Duration(milliseconds: 1600),
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    return ScaleTransition(
      scale: Tween(begin: widget.minScale, end: widget.maxScale).animate(curve),
      child: widget.child,
    );
  }
}

/// Pops its child once (a quick grow and settle) whenever [value] goes up,
/// so a badge whose count rises catches the eye. A drop, or the first
/// build, does nothing; "reduce motion" turns it off.
class PopOnIncrease extends StatefulWidget {
  const PopOnIncrease({super.key, required this.value, required this.child});

  final int value;
  final Widget child;

  @override
  State<PopOnIncrease> createState() => _PopOnIncreaseState();
}

class _PopOnIncreaseState extends State<PopOnIncrease>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween:
          Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.3, end: 1.0)
          .chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_ctrl);

  @override
  void didUpdateWidget(PopOnIncrease old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value && !reduceMotion(context)) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Floats its child up and down a few pixels.
class Float extends StatefulWidget {
  const Float({super.key, required this.child, this.distance = 6});

  final Widget child;
  final double distance;

  @override
  State<Float> createState() => _FloatState();
}

class _FloatState extends State<Float> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -widget.distance * curve.value),
        child: child,
      ),
    );
  }
}

/// List rows: the first screenful slides in one after another; rows further
/// down appear at once, so scrolling never waits on an entrance delay.
Widget staggered(int index, Widget child) =>
    index < 12 ? FadeSlideIn(index: index, child: child) : child;

/// Wraps each section of a page so they slide in one after another. Plain
/// spacers are left alone (animating empty space only adds delay).
List<Widget> staggerAll(List<Widget> children) {
  var n = 0;
  return [
    for (final child in children)
      child is SizedBox && child.child == null
          ? child
          : FadeSlideIn(index: n++, child: child),
  ];
}

/// For `Image.network(frameBuilder: fadeInFrame)`: the photo fades in over its
/// placeholder instead of popping in. Cached images and "reduce motion" show
/// at once.
Widget fadeInFrame(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded || reduceMotion(context)) return child;
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
    child: child,
  );
}

/// A number that counts up (or down) to [value] whenever it changes.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text('$value', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOut,
      builder: (_, v, __) => Text('${v.round()}', style: style),
    );
  }
}
