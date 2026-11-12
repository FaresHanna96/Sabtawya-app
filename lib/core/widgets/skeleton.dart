import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Grey placeholder rows shown while a list loads, in the shape of the rows
/// that are about to arrive, so the screen does not jump from a spinner to a
/// full list.
///
/// The rows breathe gently; with "reduce motion" on they stay still.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 6});

  final int count;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _ctrl.stop();
      _ctrl.value = 1;
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
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1).animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
          ),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: widget.count,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _SkeletonRow(short: index.isOdd),
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.short});

  /// Alternate rows get a shorter title bar, so the list does not look ruled.
  final bool short;

  static final Color _ink = AppColors.muted.withValues(alpha: 0.16);

  Widget _bar(double widthFactor, double height) => FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: _ink, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _bar(short ? 0.45 : 0.62, 13),
                  const SizedBox(height: 9),
                  _bar(short ? 0.7 : 0.85, 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
