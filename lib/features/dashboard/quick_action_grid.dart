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
  const QuickActionGrid({
    super.key,
    required this.actions,
    this.compact = false,
  });

  final List<QuickAction> actions;

  /// A bare row of tiles, no titled card around them (up to four; more
  /// still use the card). Saves a header and the card's padding.
  final bool compact;

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
    if (compact && actions.length <= 4) {
      // A small titled section: one slim row of buttons, icon beside label.
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.navy.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt_rounded, size: 16, color: AppColors.goldText),
                SizedBox(width: 4),
                Text(
                  AppStrings.quickActions,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Two to a row so a label has room (three or four in one row cut
            // «إضافة مخدوم» short); a last one on its own spans the row.
            LayoutBuilder(
              builder: (context, box) {
                final n = actions.length;
                final perRow = n <= 2 ? n : 2;
                final half = (box.maxWidth - _gap * (perRow - 1)) / perRow;
                return Wrap(
                  spacing: _gap,
                  runSpacing: _gap,
                  children: [
                    for (var i = 0; i < n; i++)
                      SizedBox(
                        width: (n > 2 && n.isOdd && i == n - 1)
                            ? box.maxWidth
                            : half,
                        child: _SlimButton(action: actions[i]),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }
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

/// A quick action as a slim button: the icon and the label side by side, 44
/// high.
class _SlimButton extends StatelessWidget {
  const _SlimButton({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.readable(action.color);
    return Material(
      color: action.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: action.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, size: 18, color: ink),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    action.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
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
