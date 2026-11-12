import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'motion.dart';

/// Splits [items] into one group per class, in [classOrder] (the order the
/// app lists classes in). Items keep their order inside each group; classes
/// with no items are left out, and items of a class not in [classOrder] come
/// last.
List<(String classId, List<T> items)> groupByClass<T>(
  List<T> items,
  String Function(T item) classOf,
  List<String> classOrder,
) {
  final byClass = <String, List<T>>{};
  for (final item in items) {
    (byClass[classOf(item)] ??= <T>[]).add(item);
  }
  return [
    for (final id in classOrder)
      if (byClass.containsKey(id)) (id, byClass.remove(id)!),
    for (final e in byClass.entries) (e.key, e.value),
  ];
}

/// The header above each class's rows when a list spans several classes:
/// a bar, the class name and how many rows it has.
class ClassGroupHeader extends StatelessWidget {
  const ClassGroupHeader({
    super.key,
    required this.name,
    required this.count,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 12, 4, 8),
  });

  final String name;
  final int count;

  /// Replaces the count on the end side when set (e.g. "حضر 8 من 12").
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: AppColors.navy.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }
}

/// A scrolling list that, when [grouped], puts [items] under a
/// [ClassGroupHeader] per class (in [classOrder]); otherwise one plain list.
///
/// The one component every screen uses for "كل الفصول" or several classes:
/// children, attendance history, birthdays and reports. [itemBuilder] gets
/// the item and its position inside its group (0-based; the whole list when
/// not grouped), e.g. for a rank that restarts per class.
class ClassGroupedList<T> extends StatelessWidget {
  const ClassGroupedList({
    super.key,
    required this.items,
    required this.grouped,
    required this.classOf,
    required this.classOrder,
    required this.classNameOf,
    required this.itemBuilder,
    this.header,
    this.leading,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 32),
    this.spacing = 8,
    this.animate = true,
  });

  final List<T> items;
  final bool grouped;
  final String Function(T item) classOf;
  final List<String> classOrder;
  final String Function(String classId) classNameOf;
  final Widget Function(BuildContext context, T item, int indexInGroup)
      itemBuilder;

  /// Custom header for a class (its items given); the default shows the
  /// class name and count.
  final Widget Function(String classId, List<T> items)? header;

  /// Shown above the list, scrolling with it (e.g. a summary line).
  final Widget? leading;
  final EdgeInsetsGeometry padding;
  final double spacing;

  /// Slides the first screenful in, one row after another.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final rows = <Object>[];
    if (leading != null) rows.add(_Leading(leading!));
    if (grouped) {
      for (final (classId, group) in groupByClass(items, classOf, classOrder)) {
        rows.add(_Header(classId, group));
        for (var i = 0; i < group.length; i++) {
          rows.add(_Item(group[i], i));
        }
      }
    } else {
      for (var i = 0; i < items.length; i++) {
        rows.add(_Item(items[i], i));
      }
    }

    return ListView.builder(
      padding: padding,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is _Leading) return row.child;
        if (row is _Header<T>) {
          return header?.call(row.classId, row.items) ??
              ClassGroupHeader(
                name: classNameOf(row.classId),
                count: row.items.length,
              );
        }
        final item = row as _Item<T>;
        final tile = itemBuilder(context, item.value, item.index);
        return Padding(
          padding: EdgeInsets.only(bottom: spacing),
          // Only the first screenful slides in, so rows further down never
          // wait on a delay.
          child: animate && index < 12
              ? FadeSlideIn(index: index, child: tile)
              : tile,
        );
      },
    );
  }
}

class _Leading {
  const _Leading(this.child);
  final Widget child;
}

class _Header<T> {
  const _Header(this.classId, this.items);
  final String classId;
  final List<T> items;
}

class _Item<T> {
  const _Item(this.value, this.index);
  final T value;
  final int index;
}
