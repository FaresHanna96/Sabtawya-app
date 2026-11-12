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
/// which classes are chosen ("كل الفصول", "5 بنات", "5 بنات، 6 بنات",
/// "3 فصول"). Tapping it opens [ClassFilterGrid] in a bottom sheet, where
/// several classes can be ticked; "تم" applies them.
///
/// [selectedIds] empty means every class. The grid used to sit on the screen
/// itself, where its two rows of chips took a large share of a phone screen.
class ClassFilterChips extends StatelessWidget {
  const ClassFilterChips({
    super.key,
    required this.classes,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<ClassFilterOption> classes;

  /// The chosen classes; empty for all of them.
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  /// What the button says for [selectedIds] out of [classes].
  static String labelFor(
      List<ClassFilterOption> classes, Set<String> selectedIds) {
    final chosen = [
      for (final c in classes)
        if (selectedIds.contains(c.id)) c.name,
    ];
    if (chosen.isEmpty || chosen.length == classes.length) {
      return AppStrings.allClasses;
    }
    if (chosen.length <= 2) return chosen.join('، ');
    return AppStrings.classesCount(chosen.length);
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ClassSheet(classes: classes, initial: selectedIds),
    );
    if (picked == null) return;
    // Every class ticked is the same as all of them.
    final next = picked.length == classes.length ? <String>{} : picked;
    if (next.length != selectedIds.length || !next.containsAll(selectedIds)) {
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen = selectedIds.isNotEmpty;
    final label = labelFor(classes, selectedIds);
    return Semantics(
      button: true,
      label: '${AppStrings.classLabel}: $label',
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
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                if (chosen)
                  // One tap back to all classes, without opening the sheet.
                  InkResponse(
                    radius: 18,
                    onTap: () => onChanged(<String>{}),
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

/// The sheet: tick classes, then "تم". "الكل" clears the ticks.
class _ClassSheet extends StatefulWidget {
  const _ClassSheet({required this.classes, required this.initial});

  final List<ClassFilterOption> classes;
  final Set<String> initial;

  @override
  State<_ClassSheet> createState() => _ClassSheetState();
}

class _ClassSheetState extends State<_ClassSheet> {
  late final Set<String> _picked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                AppStrings.pickClasses,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ),
            ClassFilterGrid(
              classes: widget.classes,
              selectedIds: _picked,
              onToggle: (id) => setState(() {
                if (id == null) {
                  _picked.clear();
                } else if (!_picked.remove(id)) {
                  _picked.add(id);
                }
              }),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_picked),
              child: Text(
                _picked.isEmpty
                    ? AppStrings.done
                    : '${AppStrings.done} (${ClassFilterChips.labelFor(widget.classes, _picked)})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
///
/// Several classes can be ticked; [onToggle] gets a class id, or null for
/// "الكل" (which is ticked while nothing else is).
class ClassFilterGrid extends StatelessWidget {
  const ClassFilterGrid({
    super.key,
    required this.classes,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<ClassFilterOption> classes;
  final Set<String> selectedIds;
  final ValueChanged<String?> onToggle;

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

        Widget slot(Widget? child) =>
            SizedBox(width: cell, height: 38, child: child);

        Widget cellFor(ClassFilterOption? c) => slot(
              c == null
                  ? null
                  : _Cell(
                      label: c.name,
                      selected: selectedIds.contains(c.id),
                      onTap: () => onToggle(c.id),
                    ),
            );

        Widget row(bool boys) => Row(
              children: [
                // "الكل" sits on the first row, an empty slot under it.
                boys
                    ? slot(_Cell(
                        label: AppStrings.all,
                        selected: selectedIds.isEmpty,
                        onTap: () => onToggle(null),
                      ))
                    : slot(null),
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
          FilterChip(
            label: const Text(AppStrings.all),
            selected: selectedIds.isEmpty,
            onSelected: (_) => onToggle(null),
          ),
          for (final c in classes)
            FilterChip(
              label: Text(c.name),
              selected: selectedIds.contains(c.id),
              onSelected: (_) => onToggle(c.id),
            ),
        ],
      );
}

/// A fixed-size grid cell that looks like a chip, with a tick when chosen.
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
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 14, color: scheme.primary),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? scheme.primary : scheme.onSurface,
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
