import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/class_filter_chips.dart';
import '../../core/widgets/class_group_header.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/reports.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import 'child_profile_screen.dart';

/// ملتزمين: children who came 3, 4 or 5+ Saturdays in a row, grouped by
/// class, longest run first. The counterpart of متابعة الغياب, under المزيد.
class CommittedChildrenScreen extends StatefulWidget {
  const CommittedChildrenScreen({super.key});

  /// The run-length choices; the last one means "or more".
  static const thresholds = [3, 4, 5];

  /// Children whose run is exactly [min] (or [min] and more for the last
  /// threshold), in [classIds] (empty = all), longest run first, then by name.
  static List<ChildStreak> filter(
    List<ChildStreak> streaks, {
    required int min,
    Set<String> classIds = const {},
  }) =>
      streaks
          .where((s) =>
              (min >= thresholds.last
                  ? s.presentStreak >= min
                  : s.presentStreak == min) &&
              (classIds.isEmpty || classIds.contains(s.classId)))
          .toList()
        ..sort((a, b) {
          final byRun = b.presentStreak.compareTo(a.presentStreak);
          return byRun != 0 ? byRun : a.childName.compareTo(b.childName);
        });

  @override
  State<CommittedChildrenScreen> createState() =>
      _CommittedChildrenScreenState();
}

class _CommittedChildrenScreenState extends State<CommittedChildrenScreen> {
  static const _reports = ReportRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<ChildStreak>>>();

  int _min = CommittedChildrenScreen.thresholds.first;
  Set<String> _classIds = <String>{};

  Future<List<ChildStreak>> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return const [];
    final streaks =
        await _reports.streaks(yearId: yearId, minAbsent: 999, minPresent: 3);
    return streaks.where((s) => s.presentStreak >= 3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<SessionController>().myClasses;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.committedStreak)),
      body: SafeArea(
        child: AsyncSection<List<ChildStreak>>(
          key: _sectionKey,
          load: _load,
          loading: const SkeletonList(),
          builder: (context, streaks, _) {
            final rows = CommittedChildrenScreen.filter(streaks,
                min: _min, classIds: _classIds);
            final several = _classIds.length > 1 ||
                (_classIds.isEmpty && classes.length > 1);
            final last = CommittedChildrenScreen.thresholds.last;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      for (final n in CommittedChildrenScreen.thresholds) ...[
                        if (n != CommittedChildrenScreen.thresholds.first)
                          const SizedBox(width: 6),
                        Expanded(
                          child: _ThresholdChip(
                            label: n == last ? '$n+' : '$n',
                            count: CommittedChildrenScreen.filter(streaks,
                                    min: n, classIds: _classIds)
                                .length,
                            selected: _min == n,
                            onTap: () => setState(() => _min = n),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (classes.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                    child: ClassFilterChips(
                      classes: [
                        for (final c in classes)
                          ClassFilterOption(id: c.classId, name: c.className),
                      ],
                      selectedIds: _classIds,
                      onChanged: (ids) => setState(() => _classIds = ids),
                    ),
                  ),
                Expanded(
                  child: rows.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 32),
                            EmptyState(
                              icon: Icons.local_fire_department_outlined,
                              title: AppStrings.noCommittedYet,
                            ),
                          ],
                        )
                      : ClassGroupedList<ChildStreak>(
                          items: rows,
                          grouped: several,
                          classOf: (s) => s.classId,
                          classOrder: [for (final c in classes) c.classId],
                          classNameOf: (id) {
                            for (final c in classes) {
                              if (c.classId == id) return c.className;
                            }
                            return '';
                          },
                          leading: const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              AppStrings.committedStreakHint,
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.muted),
                            ),
                          ),
                          itemBuilder: (context, s, _) => _CommittedTile(
                            streak: s,
                            showClass: !several,
                            onOpen: () async {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ChildProfileScreen(childId: s.childId),
                                ),
                              );
                              await _sectionKey.currentState?.reload();
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ThresholdChip extends StatelessWidget {
  const _ThresholdChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.success;
    return Material(
      color: selected ? color : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : color,
                ),
              ),
              Text(
                AppStrings.presentInARowShort(label),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommittedTile extends StatelessWidget {
  const _CommittedTile({
    required this.streak,
    required this.showClass,
    required this.onOpen,
  });

  final ChildStreak streak;
  final bool showClass;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.success;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${streak.presentStreak}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streak.childName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        if (showClass) streak.className,
                        AppStrings.presentSaturdays(streak.presentStreak),
                      ].join(' • '),
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.local_fire_department_rounded,
                  color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
