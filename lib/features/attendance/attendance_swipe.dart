import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';

/// Swipe gestures on one child's attendance line. The line springs back;
/// only the marks change.
///
/// - Towards the end (right to left in Arabic, the reading direction):
///   present at everything.
/// - Back towards the start: every mark cleared.
/// - A long press: [onLongPress] (the child's profile).
///
/// Not [enabled] (a locked Saturday, a day with no lesson): no swipe, the
/// long press still works.
class AttendanceSwipe extends StatelessWidget {
  const AttendanceSwipe({
    super.key,
    required this.id,
    required this.enabled,
    required this.onAllPresent,
    required this.onClear,
    required this.child,
    this.onLongPress,
  });

  /// Keeps each line's gesture apart (the child, and the Saturday when more
  /// than one class is on screen).
  final String id;
  final bool enabled;
  final VoidCallback onAllPresent;
  final VoidCallback onClear;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final line = onLongPress == null
        ? child
        : GestureDetector(onLongPress: onLongPress, child: child);
    if (!enabled) return line;

    // Dismissible follows the text direction: [background] is uncovered by a
    // startToEnd drag (to the left in Arabic), [secondaryBackground] by the
    // other one, each at the start / end side it uncovers.
    return Dismissible(
      key: ValueKey('attendance-swipe-$id'),
      // A deliberate swipe, not a slip while scrolling.
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          Haptics.success();
          onAllPresent();
        } else {
          Haptics.select();
          onClear();
        }
        return false;
      },
      background: const _SwipeBackground(
        alignment: AlignmentDirectional.centerStart,
        color: AppColors.success,
        icon: Icons.done_all_rounded,
        label: AppStrings.swipeAllPresent,
      ),
      secondaryBackground: const _SwipeBackground(
        alignment: AlignmentDirectional.centerEnd,
        color: AppColors.coral,
        icon: Icons.remove_done_rounded,
        label: AppStrings.swipeClear,
      ),
      child: line,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final AlignmentGeometry alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: statusTint(color),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.readable(color),
            ),
          ),
        ],
      ),
    );
  }
}
