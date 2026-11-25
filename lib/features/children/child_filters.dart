import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_sort.dart';
import '../../data/models/badges.dart';
import '../../data/models/child.dart';
import '../badges/badge_look.dart';
import 'missing_info.dart';

enum ChildSort {
  name(AppStrings.sortByName),
  age(AppStrings.sortByAge);

  const ChildSort(this.label);

  final String label;
}

/// The quick chips under the search box (one at a time).
enum QuickFilter {
  absent(AppStrings.quickAbsent),
  birthdayMonth(AppStrings.quickBirthdayMonth),
  missingInfo(AppStrings.quickMissingInfo);

  const QuickFilter(this.label);

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
    this.badge,
    this.quick,
    this.sort = ChildSort.name,
    this.ascending = true,
  });

  final String query;
  final Gender? gender;
  final bool includeInactive;

  /// Only the children who earned this badge (admin and general servant).
  final KidBadge? badge;

  /// One of the quick chips: absent, birthday this month, missing data.
  final QuickFilter? quick;
  final ChildSort sort;
  final bool ascending;

  /// Whether anything beyond the default ordering is narrowing the list.
  bool get isNarrowing =>
      query.trim().isNotEmpty ||
      gender != null ||
      includeInactive ||
      badge != null ||
      quick != null;

  ChildFilter copyWith({
    String? query,
    Gender? gender,
    bool clearGender = false,
    bool? includeInactive,
    KidBadge? badge,
    bool clearBadge = false,
    QuickFilter? quick,
    bool clearQuick = false,
    ChildSort? sort,
    bool? ascending,
  }) =>
      ChildFilter(
        query: query ?? this.query,
        gender: clearGender ? null : (gender ?? this.gender),
        includeInactive: includeInactive ?? this.includeInactive,
        badge: clearBadge ? null : (badge ?? this.badge),
        quick: clearQuick ? null : (quick ?? this.quick),
        sort: sort ?? this.sort,
        ascending: ascending ?? this.ascending,
      );

  /// Applies the search text, gender, and ordering in memory.
  ///
  /// Inactive children are filtered out here as well as in the query, so
  /// toggling the switch does not need a round trip when the caller already
  /// fetched them.
  ///
  /// [holders] are the ids of the children who earned [badge]; while it is
  /// still loading (null) the badge does not narrow anything.
  ///
  /// [absentIds] are the children absent two Saturdays or more in a row; while
  /// they load (null) the «غايب» chip does not narrow anything. [now] is the
  /// day «عيد ميلاده الشهر ده» counts from.
  List<Child> apply(
    List<Child> source, {
    Set<String>? holders,
    Set<String>? absentIds,
    DateTime? now,
  }) {
    final month = (now ?? DateTime.now()).month;
    final result = source.where((child) {
      if (!includeInactive && !child.isActive) return false;
      if (gender != null && child.gender != gender) return false;
      if (badge != null && holders != null && !holders.contains(child.id)) {
        return false;
      }
      switch (quick) {
        case QuickFilter.absent:
          if (absentIds != null && !absentIds.contains(child.id)) return false;
        case QuickFilter.birthdayMonth:
          if (child.birthDate?.month != month) return false;
        case QuickFilter.missingInfo:
          if (MissingInfo.filter([child], null).isEmpty) return false;
        case null:
          break;
      }
      return child.matches(query);
    }).toList();

    result.sort((a, b) {
      final comparison = switch (sort) {
        // In Arabic alphabet order, letter variants together.
        ChildSort.name => ArabicSort.compare(a.fullName, b.fullName),
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
    this.showGender = true,
    this.showBadges = false,
  });

  /// Offers the badge filter (admin and general servant only).
  final bool showBadges;

  /// Off for a class of only boys or only girls, where the chips do nothing.
  final bool showGender;

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
                      tooltip: AppStrings.clearSearch,
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
              // Gender, then the inactive switch as a labelled chip (an eye
              // icon alone did not say what it does).
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (showGender) ...[
                        _genderChip(null, AppStrings.all),
                        _genderChip(Gender.boy, AppStrings.boys),
                        _genderChip(Gender.girl, AppStrings.girls),
                      ],
                      if (showBadges) _badgeChip(),
                      for (final q in QuickFilter.values) _quickChip(q),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilterChip(
                          label: const Text(AppStrings.inactiveChip),
                          tooltip: AppStrings.showInactive,
                          selected: filter.includeInactive,
                          onSelected: (on) => onChanged(
                            filter.copyWith(includeInactive: on),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _badgeChip() {
    final picked = filter.badge;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      // Ids, not a nullable value: a menu never reports a null choice, so
      // «كل الشارات» could not be picked.
      child: PopupMenuButton<String>(
        tooltip: AppStrings.badgeFilter,
        initialValue: picked?.id ?? '',
        onSelected: (id) {
          final b = KidBadge.fromId(id);
          onChanged(b == null
              ? filter.copyWith(clearBadge: true)
              : filter.copyWith(badge: b));
        },
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            value: '',
            child: Text(AppStrings.allBadges),
          ),
          for (final b in KidBadge.values)
            PopupMenuItem<String>(
              value: b.id,
              child: Row(
                children: [
                  Icon(b.icon, size: 20, color: b.color),
                  const SizedBox(width: 10),
                  Text(b.title),
                ],
              ),
            ),
        ],
        child: Chip(
          avatar: Icon(
            picked?.icon ?? Icons.military_tech_outlined,
            size: 18,
            color: picked?.color ?? AppColors.muted,
          ),
          label: Text(picked?.title ?? AppStrings.badgeFilter),
          backgroundColor: picked?.color.withValues(alpha: 0.14),
        ),
      ),
    );
  }

  Widget _quickChip(QuickFilter q) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        label: Text(q.label),
        selected: filter.quick == q,
        onSelected: (on) => onChanged(
          on ? filter.copyWith(quick: q) : filter.copyWith(clearQuick: true),
        ),
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
          color: AppColors.readable(color),
        ),
      ),
    );
  }
}
