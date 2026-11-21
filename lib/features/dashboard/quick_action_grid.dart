import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';

/// One shortcut on a home page.
class QuickAction {
  const QuickAction(this.icon, this.label, this.color, this.onTap);

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// "إجراءات سريعة": equal tiles, an icon on a tinted circle with the label
/// under it. Up to four share a row; more are split into rows as even as
/// possible (5 -> 3 + 2, 7 -> 4 + 3), so no tile is left alone on a row. A
/// shorter last row keeps the same tile width and sits in the middle, and the
/// tiles of a row are equally tall even when one label takes two lines.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key, required this.actions});

  final List<QuickAction> actions;

  static const _gap = 8.0;

  /// How many tiles share a row for [count] actions.
  @visibleForTesting
  static int perRow(int count) {
    if (count <= 4) return count;
    final rows = (count / 4).ceil();
    return (count / rows).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final perRow = QuickActionGrid.perRow(actions.length);
    final rows = <List<QuickAction>>[];
    for (var i = 0; i < actions.length; i += perRow) {
      rows.add(actions.sublist(i, (i + perRow).clamp(0, actions.length)));
    }

    return SectionCard(
      title: AppStrings.quickActions,
      icon: Icons.bolt_rounded,
      accent: AppColors.gold,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = (box.maxWidth - _gap * (perRow - 1)) / perRow;
          return Column(
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) const SizedBox(height: _gap),
                IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rows[r].length; i++) ...[
                        if (i > 0) const SizedBox(width: _gap),
                        SizedBox(
                          width: width,
                          child: _Tile(action: rows[r][i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Bounce(
      onTap: action.onTap,
      child: Material(
        color: action.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: action.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, size: 20, color: action.color),
                ),
                const SizedBox(height: 6),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
