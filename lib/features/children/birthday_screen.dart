import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/child.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../state/session_controller.dart';
import 'child_profile_screen.dart';

/// Lists children whose birthday falls in one or more selected months.
///
/// Defaults to the current month. Multiple months can be selected.
class BirthdayScreen extends StatefulWidget {
  const BirthdayScreen({super.key});

  @override
  State<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends State<BirthdayScreen> {
  static const _repository = ChildRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<Child>>>();

  /// Selected months (1–12). Empty = no filter (show all).
  Set<int> _selectedMonths = {DateTime.now().month};

  String? _classFilter;

  Future<List<Child>> _load() => _repository.all(includeInactive: false);

  List<Child> _filter(List<Child> all) {
    if (_selectedMonths.isEmpty) return [];
    return all
        .where(
          (c) =>
              c.birthDate != null &&
              _selectedMonths.contains(c.birthDate!.month) &&
              (_classFilter == null || c.classId == _classFilter),
        )
        .toList()
      ..sort((a, b) {
        final da = a.birthDate!.day;
        final db = b.birthDate!.day;
        if (da != db) return da.compareTo(db);
        return a.fullName.compareTo(b.fullName);
      });
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<SessionController>().myClasses;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.birthdaysTitle)),
      body: SafeArea(
        child: Column(
          children: [
            _MonthSelector(
              selected: _selectedMonths,
              onChanged: (months) => setState(() => _selectedMonths = months),
            ),
            if (classes.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _classChip(null, AppStrings.all, classes),
                      ...classes.map(
                        (item) => _classChip(item.classId, item.className, classes),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: AsyncSection<List<Child>>(
                key: _sectionKey,
                load: _load,
                builder: (context, all, _) {
                  final visible = _filter(all);
                  if (_selectedMonths.isEmpty) {
                    return const EmptyState(
                      icon: Icons.cake_outlined,
                      title: AppStrings.birthdaysTitle,
                      body: AppStrings.birthdaysEmptyBody,
                    );
                  }
                  if (visible.isEmpty) {
                    return const EmptyState(
                      icon: Icons.cake_outlined,
                      title: AppStrings.birthdaysEmpty,
                      body: AppStrings.birthdaysEmptyBody,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _BirthdayTile(
                      child: visible[index],
                      className: _classNameOf(classes, visible[index].classId),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ChildProfileScreen(childId: visible[index].id),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classChip(String? classId, String label, List<ClassOverview> classes) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _classFilter == classId,
        onSelected: (_) => setState(() => _classFilter = classId),
      ),
    );
  }

  static String? _classNameOf(List<ClassOverview> classes, String classId) {
    for (final item in classes) {
      if (item.classId == classId) return item.className;
    }
    return null;
  }
}

// --------------------------------------------------------------- month selector

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selected,
    required this.onChanged,
  });

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cake_outlined, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(
                AppStrings.birthdaysTitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (selected.isNotEmpty && !(selected.length == 1 && selected.first == today.month))
                TextButton(
                  onPressed: () => onChanged({today.month}),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'هذا الشهر',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              if (selected.length > 1)
                GestureDetector(
                  onTap: () => onChanged({}),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'مسح (${selected.length})',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.navy.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(12, (index) {
                final month = index + 1;
                final isSelected = selected.contains(month);
                final isCurrentMonth = month == today.month;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () {
                      final next = Set<int>.from(selected);
                      if (isSelected) {
                        next.remove(month);
                      } else {
                        next.add(month);
                      }
                      onChanged(next);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.navy
                            : isCurrentMonth
                                ? AppColors.navy.withValues(alpha: 0.12)
                                : AppColors.navy.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.navy
                              : isCurrentMonth
                                  ? AppColors.navy.withValues(alpha: 0.3)
                                  : AppColors.navy.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        AppDateUtils.monthName(month),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- birthday tile

class _BirthdayTile extends StatelessWidget {
  const _BirthdayTile({
    required this.child,
    required this.onTap,
    this.className,
  });

  final Child child;
  final String? className;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final birth = child.birthDate!;
    final today = DateTime.now();
    final isToday = birth.month == today.month && birth.day == today.day;
    final nextAge = today.year - birth.year +
        (DateTime(today.year, birth.month, birth.day).isBefore(today) ? 1 : 0);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: _DayBadge(day: birth.day, isToday: isToday),
        title: Text(
          child.fullName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (className != null) className!,
            '${AppStrings.turningAge} $nextAge ${AppStrings.years}',
          ].join(' • '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: isToday
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cake, size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.birthdayToday,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}

// ----------------------------------------------------------------- day badge

class _DayBadge extends StatelessWidget {
  const _DayBadge({required this.day, required this.isToday});

  final int day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.warning.withValues(alpha: 0.15)
            : AppColors.navy.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$day',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: isToday ? AppColors.warning : AppColors.navy,
        ),
      ),
    );
  }
}
