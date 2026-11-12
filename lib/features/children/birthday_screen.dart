import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/motion.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/class_filter_chips.dart';
import '../../data/models/child.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../data/services/excel_service.dart';
import '../../data/services/file_service.dart';
import '../../state/session_controller.dart';
import 'child_avatar.dart';
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

  static const _servantRepository = ServantRepository();
  static const _classRepository = ClassRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<_Person>>>();

  /// false = children (المخدومين), true = servants (الخدام).
  bool _servants = false;

  /// Selected months (1–12). Empty = no filter (show all).
  Set<int> _selectedMonths = {DateTime.now().month};

  /// The classes chosen; empty is all of them.
  Set<String> _classFilter = <String>{};

  /// Everyone loaded for the current tab, kept so the export writes exactly
  /// the list on screen (same months, class and order).
  List<_Person> _all = const [];
  bool _exporting = false;

  Future<List<_Person>> _load() async {
    if (!_servants) {
      final children = await _repository.all(includeInactive: false);
      return [
        for (final c in children)
          if (c.birthDate != null)
            _Person(
              name: c.fullName,
              birth: c.birthDate!,
              classIds: [c.classId],
              childId: c.id,
              mobile: c.mobile,
              child: c,
            ),
      ];
    }
    final servants = await _servantRepository.birthdays();
    final assignments = await _classRepository.allAssignments();
    return [
      for (final p in servants)
        if (p.birthDate != null)
          _Person(
            name: p.fullName,
            birth: p.birthDate!,
            classIds: [
              for (final a in assignments)
                if (a.servantId == p.id) a.classId,
            ],
            role: p.roleLabel,
            mobile: p.mobile,
          ),
    ];
  }

  Future<void> _export(List<ClassOverview> classes) async {
    final visible = _filter(_all);
    if (_exporting) return;
    if (visible.isEmpty) {
      Ui.info(context, AppStrings.noData);
      return;
    }
    final rows = [
      for (final p in visible)
        BirthdayRow(
          name: p.name,
          birthDate: p.birth,
          turningAge: turningAge(p.birth, DateTime.now()),
          role: p.role,
          mobile: p.mobile,
          className: p.classIds
              .map((id) => _classNameOf(classes, id))
              .whereType<String>()
              .join('، '),
        ),
    ];
    final months = (_selectedMonths.toList()..sort())
        .map(AppDateUtils.monthName)
        .join('، ');
    String? classPart;
    if (_classFilter.isNotEmpty) {
      classPart = ClassFilterChips.labelFor(_options(classes), _classFilter);
    }
    final name = [
      AppStrings.birthdaysTitle,
      _servants
          ? AppStrings.servantBirthdaysShort
          : AppStrings.childBirthdaysShort,
      if (classPart != null) classPart,
      months,
    ].join(' - ');

    setState(() => _exporting = true);
    try {
      await FileService.saveAndShare(
        fileName: FileService.timestampedName(name),
        bytes: ExcelService.birthdaysWorkbook(rows, servants: _servants),
        shareText: name,
      );
      if (mounted) Ui.success(context, AppStrings.exportDone);
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<_Person> _filter(List<_Person> all) {
    if (_selectedMonths.isEmpty) return [];
    return all
        .where(
          (c) =>
              _selectedMonths.contains(c.birth.month) &&
              (_classFilter.isEmpty || c.classIds.any(_classFilter.contains)),
        )
        .toList()
      ..sort((a, b) {
        if (a.birth.month != b.birth.month) {
          return a.birth.month.compareTo(b.birth.month);
        }
        if (a.birth.day != b.birth.day) {
          return a.birth.day.compareTo(b.birth.day);
        }
        return a.name.compareTo(b.name);
      });
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<SessionController>().myClasses;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.birthdaysTitle),
        actions: [
          // Exports the list on screen: the tab, months and class chosen.
          IconButton(
            tooltip: AppStrings.exportTitle,
            onPressed: _exporting ? null : () => _export(classes),
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.child_care),
                    label: Text(AppStrings.childBirthdaysShort),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.volunteer_activism_outlined),
                    label: Text(AppStrings.servantBirthdaysShort),
                  ),
                ],
                selected: {_servants},
                onSelectionChanged: (value) => setState(() {
                  _servants = value.first;
                  _classFilter = <String>{};
                  _sectionKey.currentState?.reload();
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterButton(
                      icon: Icons.calendar_month_outlined,
                      label: _monthsLabel(),
                      onTap: _pickMonths,
                    ),
                  ),
                  if (!_servants && classes.length > 1) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClassFilterChips(
                        classes: _options(classes),
                        selectedIds: _classFilter,
                        onChanged: (ids) => setState(() => _classFilter = ids),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: AsyncSection<List<_Person>>(
                key: _sectionKey,
                load: _load,
                builder: (context, all, _) {
                  _all = all;
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
                  // A month header before each month's first birthday, when
                  // more than one month is shown.
                  final grouped = _selectedMonths.length > 1;
                  final items = <Object>[];
                  for (final p in visible) {
                    if (grouped &&
                        (items.isEmpty ||
                            (items.last as _Person).birth.month !=
                                p.birth.month)) {
                      items.add(p.birth.month);
                    }
                    items.add(p);
                  }
                  final todayCount =
                      visible.where((p) => _isToday(p.birth)).length;

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _Summary(
                          count: visible.length,
                          todayCount: todayCount,
                        );
                      }
                      final item = items[index - 1];
                      if (item is int) return _MonthHeader(month: item);
                      final person = item as _Person;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: staggered(
                          index,
                          _BirthdayTile(
                            person: person,
                            showMonth: grouped,
                            className: person.classIds
                                .map((id) => _classNameOf(classes, id))
                                .whereType<String>()
                                .join('، '),
                            onTap: person.childId == null
                                ? null
                                : () => Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ChildProfileScreen(
                                          childId: person.childId!,
                                        ),
                                      ),
                                    ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "نوفمبر", "نوفمبر، ديسمبر", "4 شهور" or "السنة كلها".
  String _monthsLabel() {
    final months = _selectedMonths.toList()..sort();
    if (months.isEmpty) return AppStrings.pickMonths;
    if (months.length == 12) return AppStrings.wholeYear;
    if (months.length <= 2) {
      return months.map(AppDateUtils.monthName).join('، ');
    }
    return AppStrings.monthsCount(months.length);
  }

  Future<void> _pickMonths() async {
    var picked = Set<int>.from(_selectedMonths);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MonthSelector(
                  selected: picked,
                  onChanged: (months) {
                    setSheet(() => picked = months);
                    setState(() => _selectedMonths = months);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text(AppStrings.done),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<ClassFilterOption> _options(List<ClassOverview> classes) => [
        for (final c in classes)
          ClassFilterOption(id: c.classId, name: c.className),
      ];

  static bool _isToday(DateTime birth) {
    final now = DateTime.now();
    return birth.month == now.month && birth.day == now.day;
  }

  static String? _classNameOf(List<ClassOverview> classes, String classId) {
    for (final item in classes) {
      if (item.classId == classId) return item.className;
    }
    return null;
  }
}

// --------------------------------------------------------------- month selector

/// All twelve months at once (two rows of six), so the chosen month is never
/// scrolled out of sight. The current month carries a dot.
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
    final onlyThisMonth = selected.length == 1 && selected.first == today.month;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              const Text(
                AppStrings.pickMonths,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!onlyThisMonth)
                _LinkButton(
                  label: AppStrings.thisMonth,
                  onTap: () => onChanged({today.month}),
                ),
              if (selected.length < 12)
                _LinkButton(
                  label: AppStrings.wholeYear,
                  onTap: () => onChanged({for (var m = 1; m <= 12; m++) m}),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final row in const [
            [1, 2, 3, 4, 5, 6],
            [7, 8, 9, 10, 11, 12],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    Expanded(
                      child: _MonthChip(
                        month: row[i],
                        selected: selected.contains(row[i]),
                        current: row[i] == today.month,
                        onTap: () {
                          final next = Set<int>.from(selected);
                          if (!next.remove(row[i])) next.add(row[i]);
                          onChanged(next);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.month,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final int month;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: AppDateUtils.monthName(month),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.navy
                  : AppColors.navy.withValues(alpha: current ? 0.10 : 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.navy
                    : AppColors.navy.withValues(alpha: current ? 0.35 : 0.10),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      AppDateUtils.monthName(month),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ),
                ),
                if (current)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? Colors.white : AppColors.coral,
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

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// "12 عيد ميلاد  🎂 2 اليوم" above the list.
class _Summary extends StatelessWidget {
  const _Summary({required this.count, required this.todayCount});

  final int count;
  final int todayCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Row(
        children: [
          Text(
            AppStrings.birthdaysCount(count),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          if (todayCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '🎂 $todayCount ${AppStrings.todayShort}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month});

  final int month;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Text(
            AppDateUtils.monthName(month),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- birthday tile

/// One birthday: a child or a servant.
class _Person {
  const _Person({
    required this.name,
    required this.birth,
    required this.classIds,
    this.childId,
    this.role,
    this.mobile,
    this.child,
  });

  final String name;
  final DateTime birth;
  final List<String> classIds;

  /// Set for a child, so the tile can open the profile.
  final String? childId;

  /// Set for a servant (أمين الخدمة / خادم / خادم عام).
  final String? role;
  final String? mobile;

  /// The child record (children tab only), for the photo avatar.
  final Child? child;
}

/// The age a person turns on their next birthday (today counts as next).
int turningAge(DateTime birth, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  final thisYear = DateTime(today.year, birth.month, birth.day);
  return today.year - birth.year + (thisYear.isBefore(day) ? 1 : 0);
}

class _BirthdayTile extends StatelessWidget {
  const _BirthdayTile({
    required this.person,
    required this.onTap,
    this.className,
    this.showMonth = false,
  });

  final _Person person;
  final String? className;
  final VoidCallback? onTap;

  /// Adds the month under the day when several months are listed.
  final bool showMonth;

  @override
  Widget build(BuildContext context) {
    final birth = person.birth;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisYear = DateTime(now.year, birth.month, birth.day);
    final daysLeft = thisYear.difference(today).inDays;
    final isToday = daysLeft == 0;
    // Already celebrated this year: still listed, but quieter.
    final passed = daysLeft < 0;
    final nextAge = turningAge(birth, now);
    final hasPhone = (person.mobile ?? '').trim().isNotEmpty;

    final String status;
    final Color statusColor;
    if (isToday) {
      status = '🎂 ${AppStrings.birthdayToday}';
      statusColor = AppColors.warning;
    } else if (passed) {
      status = AppStrings.birthdayPassed;
      statusColor = AppColors.muted;
    } else {
      status = daysLeft == 1
          ? AppStrings.birthdayTomorrow
          : AppStrings.birthdayInDays(daysLeft);
      statusColor = daysLeft <= 7 ? AppColors.coral : AppColors.navyLight;
    }

    return Opacity(
      opacity: passed ? 0.6 : 1,
      child: Card(
        margin: EdgeInsets.zero,
        color: isToday ? AppColors.goldTint : null,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsetsDirectional.only(start: 12, end: 4),
          leading: person.child == null
              ? _DayBadge(
                  day: birth.day,
                  month: showMonth ? birth.month : null,
                  isToday: isToday,
                )
              : _AvatarWithDay(
                  child: person.child!,
                  day: birth.day,
                  month: showMonth ? birth.month : null,
                  isToday: isToday,
                ),
          title: Text(
            person.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (person.role != null) person.role!,
                  if (className != null && className!.isNotEmpty) className!,
                  '${AppStrings.turningAge} $nextAge ${AppStrings.years}',
                ].join(' • '),
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPhone)
                IconButton(
                  tooltip: AppStrings.call,
                  icon: const Icon(Icons.call_rounded, size: 20),
                  color: AppColors.success,
                  onPressed: () => launchUrl(
                    Uri(scheme: 'tel', path: person.mobile!.trim()),
                  ),
                ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsetsDirectional.only(end: 6),
                  child: Icon(AppIcons.forward, color: AppColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- day badge

class _DayBadge extends StatelessWidget {
  const _DayBadge({required this.day, required this.isToday, this.month});

  final int day;
  final int? month;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final color = isToday ? AppColors.warning : AppColors.navy;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.warning.withValues(alpha: 0.15)
            : AppColors.navy.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$day',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: month == null ? 15 : 14,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (month != null)
            SizedBox(
              width: 38,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  AppDateUtils.monthName(month!),
                  style: TextStyle(fontSize: 12, height: 1.1, color: color),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A child's photo (or initials) with the birthday's day on a pill below.
class _AvatarWithDay extends StatelessWidget {
  const _AvatarWithDay({
    required this.child,
    required this.day,
    required this.isToday,
    this.month,
  });

  final Child child;
  final int day;
  final int? month;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final color = isToday ? AppColors.warning : AppColors.navy;
    final label =
        month == null ? '$day' : '$day ${AppDateUtils.monthName(month!)}';
    return SizedBox(
      width: 52,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          ChildAvatar(child: child, size: 44),
          Positioned(
            bottom: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 26, maxWidth: 52),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isToday ? AppColors.warning : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isToday ? Colors.white : color,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact filter: what is chosen, with a hint it can be changed.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navy.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.navy.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.navy),
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
              const Icon(Icons.expand_more, size: 20, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
