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
/// under it. Up to four share a row; more wrap into rows of three or four so
/// every tile keeps the same width and nothing scrolls sideways.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final perRow = actions.length <= 4
        ? actions.length
        : (actions.length % 3 == 0 ? 3 : 4);
    final rows = <List<QuickAction>>[];
    for (var i = 0; i < actions.length; i += perRow) {
      rows.add(actions.sublist(i, (i + perRow).clamp(0, actions.length)));
    }

    return SectionCard(
      title: AppStrings.quickActions,
      icon: Icons.bolt_rounded,
      accent: AppColors.gold,
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < perRow; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: i < rows[r].length
                        ? _Tile(action: rows[r][i])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
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
                    fontSize: 11.5,
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
