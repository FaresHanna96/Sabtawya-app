import 'package:flutter/material.dart';

/// A round button with a tinted fill, for one action beside a person or a
/// place: call, WhatsApp, open the map. [size] is 48 by default (a thumb); the
/// lists of people use 42.
class RoundActionButton extends StatelessWidget {
  const RoundActionButton({
    super.key,
    required this.tooltip,
    required this.color,
    required this.onTap,
    required this.child,
    this.size = 48,
  });

  final String tooltip;

  /// The tint of the fill; the [child] brings its own colour.
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: color.withValues(alpha: 0.14),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
