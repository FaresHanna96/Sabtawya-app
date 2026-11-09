import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// One class to pick from.
class ClassFilterOption {
  const ClassFilterOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// Class filter laid out as a tidy grid instead of a ragged row of chips.
///
/// Names like "5 ولاد" / "5 بنات" go in a grid: one column per year, boys on
/// the first row and girls on the second, with "الكل" beside them. Every cell
/// has the same width, so nothing needs swiping and the eye finds a class by
/// year. When the names do not follow that pattern the chips simply wrap.
class ClassFilterChips extends StatelessWidget {
  const ClassFilterChips({
    super.key,
    required this.classes,
    required this.selectedId,
    required this.onSelected,
  });

  final List<ClassFilterOption> classes;

  /// The chosen class, or null for "all".
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  static final _pattern = RegExp(r'^\s*(\d+)\s*(ولاد|بنات)\s*$');

  @override
  Widget build(BuildContext context) {
    final parsed = <ClassFilterOption, (int, bool)>{};
    for (final c in classes) {
      final m = _pattern.firstMatch(c.name);
      if (m == null) return _wrap();
      parsed[c] = (int.parse(m.group(1)!), m.group(2) == 'ولاد');
    }

    final years = parsed.values.map((v) => v.$1).toSet().toList()..sort();
    ClassFilterOption? find(int year, bool boys) {
      for (final e in parsed.entries) {
        if (e.value.$1 == year && e.value.$2 == boys) return e.key;
      }
      return null;
    }

    return LayoutBuilder(
      builder: (context, box) {
        const gap = 6.0;
        final columns = years.length + 1; // + "الكل"
        final cell = (box.maxWidth - gap * (columns - 1)) / columns;

        Widget slot(Widget? child) => SizedBox(width: cell, height: 38, child: child);

        Widget cellFor(ClassFilterOption? c) => slot(
              c == null
                  ? null
                  : _Cell(
                      label: c.name,
                      selected: selectedId == c.id,
                      onTap: () => onSelected(c.id),
                    ),
            );

        Widget row(bool boys) => Row(
              children: [
                // "الكل" sits on the first row, an empty slot under it.
                if (boys)
                  slot(_Cell(
                    label: AppStrings.all,
                    selected: selectedId == null,
                    onTap: () => onSelected(null),
                  ))
                else
                  slot(null),
                for (final y in years) ...[
                  const SizedBox(width: gap),
                  cellFor(find(y, boys)),
                ],
              ],
            );

        return Column(
          children: [
            row(true),
            const SizedBox(height: gap),
            row(false),
          ],
        );
      },
    );
  }

  Widget _wrap() => Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _Chip(
            label: AppStrings.all,
            selected: selectedId == null,
            onTap: () => onSelected(null),
          ),
          for (final c in classes)
            _Chip(
              label: c.name,
              selected: selectedId == c.id,
              onTap: () => onSelected(c.id),
            ),
        ],
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      );
}

/// A fixed-size grid cell that looks like a chip.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected
              ? scheme.primary.withValues(alpha: 0.6)
              : scheme.outlineVariant,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? scheme.primary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
