import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/child.dart';

enum ChildSort {
  name(AppStrings.sortByName),
  age(AppStrings.sortByAge);

  const ChildSort(this.label);

  final String label;
}

/// The filter state shared by the children list and the class details page.
///
/// Kept immutable so a screen can hold one field and rebuild from
/// `filter.copyWith(...)` instead of juggling several booleans.
class ChildFilter {
  const ChildFilter({
    this.query = '',
    this.gender,
    this.includeInactive = false,
    this.sort = ChildSort.name,
    this.ascending = true,
  });

  final String query;
  final Gender? gender;
  final bool includeInactive;
  final ChildSort sort;
  final bool ascending;

  /// Whether anything beyond the default ordering is narrowing the list.
  bool get isNarrowing =>
      query.trim().isNotEmpty || gender != null || includeInactive;

  ChildFilter copyWith({
    String? query,
    Gender? gender,
    bool clearGender = false,
    bool? includeInactive,
    ChildSort? sort,
    bool? ascending,
  }) =>
      ChildFilter(
        query: query ?? this.query,
        gender: clearGender ? null : (gender ?? this.gender),
        includeInactive: includeInactive ?? this.includeInactive,
        sort: sort ?? this.sort,
        ascending: ascending ?? this.ascending,
      );

  /// Applies the search text, gender, and ordering in memory.
  ///
  /// Inactive children are filtered out here as well as in the query, so
  /// toggling the switch does not need a round trip when the caller already
  /// fetched them.
  List<Child> apply(List<Child> source) {
    final result = source.where((child) {
      if (!includeInactive && !child.isActive) return false;
      if (gender != null && child.gender != gender) return false;
      return child.matches(query);
    }).toList();

    result.sort((a, b) {
      final comparison = switch (sort) {
        ChildSort.name => a.fullName.compareTo(b.fullName),
        // Children with no birth date sort last either way.
        ChildSort.age => _compareNullableInt(a.ageYears, b.ageYears),
      };
      return ascending ? comparison : -comparison;
    });

    return result;
  }

  static int _compareNullableInt(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}

/// Search field, gender chips, inactive toggle, and sort control.
class ChildFilterBar extends StatelessWidget {
  const ChildFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.searchController,
    this.resultCount,
    this.totalCount,
  });

  final ChildFilter filter;
  final ValueChanged<ChildFilter> onChanged;
  final TextEditingController searchController;
  final int? resultCount;
  final int? totalCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            onChanged: (value) => onChanged(filter.copyWith(query: value)),
            decoration: InputDecoration(
              hintText: AppStrings.searchChildHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: filter.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        onChanged(filter.copyWith(query: ''));
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _genderChip(null, AppStrings.all),
                      _genderChip(Gender.boy, AppStrings.boys),
                      _genderChip(Gender.girl, AppStrings.girls),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: AppStrings.showInactive,
                isSelected: filter.includeInactive,
                onPressed: () => onChanged(
                  filter.copyWith(includeInactive: !filter.includeInactive),
                ),
                icon: const Icon(Icons.visibility_off_outlined),
                selectedIcon: const Icon(Icons.visibility),
              ),
              PopupMenuButton<ChildSort>(
                tooltip: AppStrings.sortBy,
                icon: const Icon(Icons.sort),
                initialValue: filter.sort,
                onSelected: (sort) => onChanged(
                  // Tapping the active option flips the direction.
                  sort == filter.sort
                      ? filter.copyWith(ascending: !filter.ascending)
                      : filter.copyWith(sort: sort, ascending: true),
                ),
                itemBuilder: (context) => ChildSort.values
                    .map(
                      (sort) => PopupMenuItem<ChildSort>(
                        value: sort,
                        child: Row(
                          children: [
                            Expanded(child: Text(sort.label)),
                            if (sort == filter.sort)
                              Icon(
                                filter.ascending
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 16,
                                color: AppColors.navy,
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          if (resultCount != null && filter.isNarrowing) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  totalCount == null
                      ? '$resultCount ${AppStrings.resultsCount}'
                      : '${AppStrings.showingOf} $resultCount / $totalCount',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    searchController.clear();
                    onChanged(const ChildFilter());
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: const Text(
                    AppStrings.clearFilters,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _genderChip(Gender? value, String label) {
    final selected = filter.gender == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onChanged(
          value == null
              ? filter.copyWith(clearGender: true)
              : filter.copyWith(gender: value),
        ),
      ),
    );
  }
}

/// Small coloured badge showing ولد / بنت.
class GenderBadge extends StatelessWidget {
  const GenderBadge({super.key, required this.gender, this.compact = false});

  final Gender gender;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = gender == Gender.boy ? AppColors.navyLight : AppColors.olive;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        gender.label,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
