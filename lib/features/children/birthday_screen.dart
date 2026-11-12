import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/motion.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../data/services/excel_service.dart';
import '../../data/services/file_service.dart';
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

  static const _servantRepository = ServantRepository();
  static const _classRepository = ClassRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<_Person>>>();

  /// false = children (المخدومين), true = servants (الخدام).
  bool _servants = false;

  /// Selected months (1–12). Empty = no filter (show all).
  Set<int> _selectedMonths = {DateTime.now().month};

  String? _classFilter;

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
    if (_classFilter != null) classPart = _classNameOf(classes, _classFilter!);
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
              (_classFilter == null || c.classIds.contains(_classFilter)),
        )
        .toList()
      ..sort((a, b) {
        final da = a.birth.day;
        final db = b.birth.day;
        if (da != db) return da.compareTo(db);
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
                  _classFilter = null;
                  _sectionKey.currentState?.reload();
                }),
              ),
            ),
            _MonthSelector(
              selected: _selectedMonths,
              onChanged: (months) => setState(() => _selectedMonths = months),
            ),
            if (!_servants && classes.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _classChip(null, AppStrings.all, classes),
                      ...classes.map(
                        (item) =>
                            _classChip(item.classId, item.className, classes),
                      ),
                    ],
                  ),
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
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => FadeSlideIn(
                      index: index,
                      child: _BirthdayTile(
                        person: visible[index],
                        className: visible[index]
                            .classIds
                            .map((id) => _classNameOf(classes, id))
                            .whereType<String>()
                            .join('، '),
                        onTap: visible[index].childId == null
                            ? null
                            : () => Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ChildProfileScreen(
                                      childId: visible[index].childId!,
                                    ),
                                  ),
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

  Widget _classChip(
      String? classId, String label, List<ClassOverview> classes) {
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
              if (selected.isNotEmpty &&
                  !(selected.length == 1 && selected.first == today.month))
                TextButton(
                  onPressed: () => onChanged({today.month}),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

/// One birthday: a child or a servant.
class _Person {
  const _Person({
    required this.name,
    required this.birth,
    required this.classIds,
    this.childId,
    this.role,
    this.mobile,
  });

  final String name;
  final DateTime birth;
  final List<String> classIds;

  /// Set for a child, so the tile can open the profile.
  final String? childId;

  /// Set for a servant (أمين الخدمة / خادم / خادم عام).
  final String? role;
  final String? mobile;
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
  });

  final _Person person;
  final String? className;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final birth = person.birth;
    final today = DateTime.now();
    final isToday = birth.month == today.month && birth.day == today.day;
    final nextAge = turningAge(birth, today);

    return Card(
      margin: EdgeInsets.zero,
      color: isToday ? AppColors.goldTint : null,
      child: ListTile(
        onTap: onTap,
        leading: _DayBadge(day: birth.day, isToday: isToday),
        title: Text(
          person.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (person.role != null) person.role!,
            if (className != null && className!.isNotEmpty) className!,
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
                    const Pulse(
                      child: Text('🎂', style: TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.birthdayToday,
                      style: TextStyle(
                        fontSize: 12,
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
