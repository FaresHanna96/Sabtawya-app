import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// One class to pick from.
class ClassFilterOption {
  const ClassFilterOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// The class filter every list screen shows: one compact button that says
/// which class is chosen ("كل الفصول" / "5 بنات"). Tapping it opens the full
/// [ClassFilterGrid] in a bottom sheet; picking a class closes the sheet.
///
/// The grid used to sit on the screen itself, where its two rows of chips
/// took a large share of a phone screen above every list.
class ClassFilterChips extends StatelessWidget {
  const ClassFilterChips({
    super.key,
    required this.classes,
    required this.selectedId,
    required this.onSelected,
    this.showAll = true,
  });

  final List<ClassFilterOption> classes;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  /// Off where one class must always be chosen (e.g. attendance history).
  final bool showAll;

  String get _label {
    for (final c in classes) {
      if (c.id == selectedId) return c.name;
    }
    return showAll ? AppStrings.allClasses : AppStrings.selectClass;
  }

  Future<void> _open(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ClassFilterGrid(
            classes: classes,
            selectedId: selectedId,
            showAll: showAll,
            onSelected: (id) {
              Navigator.of(sheetContext).pop();
              if (id != selectedId) onSelected(id);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chosen = selectedId != null;
    return Semantics(
      button: true,
      label: '${AppStrings.classLabel}: $_label',
      excludeSemantics: true,
      child: Material(
        color: chosen
            ? AppColors.navy.withValues(alpha: 0.10)
            : AppColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(context),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.navy.withValues(alpha: chosen ? 0.35 : 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.class_outlined,
                    size: 18, color: AppColors.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                if (chosen && showAll)
                  // One tap back to all classes, without opening the sheet.
                  InkResponse(
                    radius: 18,
                    onTap: () => onSelected(null),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child:
                          Icon(Icons.close, size: 18, color: AppColors.muted),
                    ),
                  ),
                const Icon(Icons.expand_more, size: 20, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Class filter laid out as a tidy grid instead of a ragged row of chips.
///
/// Names like "5 ولاد" / "5 بنات" go in a grid: one column per year, boys on
/// the first row and girls on the second, with "الكل" beside them. Every cell
/// has the same width, so nothing needs swiping and the eye finds a class by
/// year. When the names do not follow that pattern the chips simply wrap.
class ClassFilterGrid extends StatelessWidget {
  const ClassFilterGrid({
    super.key,
    required this.classes,
    required this.selectedId,
    required this.onSelected,
    this.showAll = true,
  });

  /// Off where one class must always be chosen (e.g. attendance history).
  final bool showAll;

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
        final columns = years.length + (showAll ? 1 : 0); // + "الكل"
        final cell = (box.maxWidth - gap * (columns - 1)) / columns;

        Widget slot(Widget? child) =>
            SizedBox(width: cell, height: 38, child: child);

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
                if (showAll)
                  boys
                      ? slot(_Cell(
                          label: AppStrings.all,
                          selected: selectedId == null,
                          onTap: () => onSelected(null),
                        ))
                      : slot(null),
                for (final (i, y) in years.indexed) ...[
                  if (showAll || i > 0) const SizedBox(width: gap),
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
          if (showAll)
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
