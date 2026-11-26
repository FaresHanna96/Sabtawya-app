import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// One tab of [AppNavBar].
class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.color,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;

  /// The tab's own colour: its pill and, darkened, its label when selected.
  final Color color;
  final Widget icon;
  final Widget selectedIcon;
}

/// The floating bottom bar: a rounded white card, with a pill in the tab's
/// colour behind the selected icon.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.onLongPress,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// A long press on a tab: its shortcuts.
  final ValueChanged<int>? onLongPress;

  @override
  Widget build(BuildContext context) {
    // Large text settings still fit six tabs on a narrow phone.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: AppColors.navy.withValues(alpha: 0.07),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navy.withValues(alpha: 0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        for (final (i, item) in items.indexed)
                          Expanded(
                            child: _NavButton(
                              item: item,
                              selected: i == selectedIndex,
                              onTap: () => onSelected(i),
                              onLongPress: onLongPress == null
                                  ? null
                                  : () => onLongPress!(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = Duration(milliseconds: still ? 0 : 280);
    return Semantics(
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: 36,
        highlightColor: item.color.withValues(alpha: 0.08),
        splashColor: item.color.withValues(alpha: 0.14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The pill grows out from behind the icon.
                    AnimatedContainer(
                      duration: duration,
                      curve: Curves.easeOutBack,
                      width: selected ? 52 : 24,
                      height: 32,
                      decoration: BoxDecoration(
                        color:
                            item.color.withValues(alpha: selected ? 0.18 : 0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    selected ? item.selectedIcon : item.icon,
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    style: DefaultTextStyle.of(context).style.copyWith(
                          fontSize: 11.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected ? AppColors.navy : AppColors.muted,
                        ),
                    child: Text(item.label, maxLines: 1, softWrap: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
