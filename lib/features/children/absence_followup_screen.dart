import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/class_filter_chips.dart';
import '../../core/widgets/class_group_header.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/child.dart';
import '../../data/models/reports.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import 'child_profile_screen.dart';

/// متابعة الغياب: children absent 2, 3 or 4+ Saturdays in a row, grouped by
/// class, worst first, with a call button and "تم الافتقاد", which records a
/// phone or home visit in the child's visit history.
class AbsenceFollowUpScreen extends StatefulWidget {
  const AbsenceFollowUpScreen({super.key});

  @override
  State<AbsenceFollowUpScreen> createState() => _AbsenceFollowUpScreenState();
}

class _AbsenceFollowUpScreenState extends State<AbsenceFollowUpScreen> {
  static const _reports = ReportRepository();
  static const _children = ChildRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_Data>>();

  /// The least number of Saturdays in a row: 2, 3 or 4 (4 = "4+").
  int _min = 2;
  Set<String> _classIds = <String>{};

  Future<_Data> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return const _Data([], {});
    final (streaks, children) = await (
      _reports.streaks(yearId: yearId, minAbsent: 2, minPresent: 999),
      _children.all(includeInactive: false),
    ).wait;
    return _Data(
      streaks.where((s) => s.absentStreak >= 2).toList(),
      {for (final c in children) c.id: c},
    );
  }

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _markFollowedUp(ChildStreak s, Child? child) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '${AppStrings.followUpHow} ${s.childName}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.call_rounded, color: AppColors.success),
              title: const Text(AppStrings.followUpPhone),
              onTap: () => Navigator.of(sheet).pop('phone'),
            ),
            ListTile(
              leading: const Icon(Icons.home_rounded, color: AppColors.navy),
              title: const Text(AppStrings.followUpHome),
              onTap: () => Navigator.of(sheet).pop('home'),
            ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    final today = AppDateUtils.dateOnly(DateTime.now());
    final note = AppStrings.followUpNote(s.absentStreak);
    final ok = await Ui.runGuarded(
      context,
      () async {
        // Same as saving a visit on the child's profile: the child's last
        // visit, and an entry in the visit history.
        if (child != null) {
          await _children.update(child.withVisits(
            phoneVisitDate: type == 'phone' ? today : child.lastPhoneVisitDate,
            phoneVisitNotes: type == 'phone' ? note : child.lastPhoneVisitNotes,
            homeVisitDate: type == 'home' ? today : child.lastHomeVisitDate,
            homeVisitNotes: type == 'home' ? note : child.lastHomeVisitNotes,
          ));
        }
        await _children.recordVisitLog(
          childId: s.childId,
          visitType: type,
          visitDate: today,
          notes: note,
        );
      },
      successMessage: AppStrings.saved,
    );
    if (ok) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<SessionController>().myClasses;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.absenceFollowUp)),
      body: SafeArea(
        child: AsyncSection<_Data>(
          key: _sectionKey,
          load: _load,
          loading: const SkeletonList(),
          builder: (context, data, _) {
            final rows = data.streaks
                .where((s) =>
                    s.absentStreak >= _min &&
                    (_classIds.isEmpty || _classIds.contains(s.classId)))
                .toList()
              ..sort((a, b) => b.absentStreak.compareTo(a.absentStreak));
            final several = _classIds.length > 1 ||
                (_classIds.isEmpty && classes.length > 1);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      for (final n in const [2, 3, 4]) ...[
                        if (n > 2) const SizedBox(width: 6),
                        Expanded(
                          child: _ThresholdChip(
                            label: n == 4 ? '4+' : '$n',
                            count: data.streaks
                                .where((s) =>
                                    s.absentStreak >= n &&
                                    (_classIds.isEmpty ||
                                        _classIds.contains(s.classId)))
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
                              icon: Icons.volunteer_activism_outlined,
                              title: AppStrings.noAbsences,
                              body: AppStrings.noAbsencesBody,
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
                          itemBuilder: (context, s, _) => _AbsenceTile(
                            streak: s,
                            child: data.children[s.childId],
                            showClass: !several,
                            onFollowedUp: () =>
                                _markFollowedUp(s, data.children[s.childId]),
                            onOpen: () async {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ChildProfileScreen(childId: s.childId),
                                ),
                              );
                              await _reload();
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

class _Data {
  const _Data(this.streaks, this.children);

  final List<ChildStreak> streaks;
  final Map<String, Child> children;
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
    final color = AppColors.coral;
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
                AppStrings.absentInARowShort(label),
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

class _AbsenceTile extends StatelessWidget {
  const _AbsenceTile({
    required this.streak,
    required this.child,
    required this.showClass,
    required this.onFollowedUp,
    required this.onOpen,
  });

  final ChildStreak streak;
  final Child? child;
  final bool showClass;
  final VoidCallback onFollowedUp;
  final VoidCallback onOpen;

  /// The last phone or home visit, whichever is newer.
  DateTime? get _lastVisit {
    final a = child?.lastPhoneVisitDate;
    final b = child?.lastHomeVisitDate;
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  String? get _phone {
    for (final n in [child?.mobile, child?.motherMobile, child?.fatherMobile]) {
      if ((n ?? '').trim().isNotEmpty) return n!.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final visit = _lastVisit;
    final lastPresent = streak.lastPresentDate;
    // Followed up already if someone visited after the last time they came.
    final followed =
        visit != null && (lastPresent == null || !visit.isBefore(lastPresent));
    final color = streak.absentStreak >= 4
        ? AppColors.danger
        : streak.absentStreak == 3
            ? AppColors.coral
            : AppColors.warning;
    final phone = _phone;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
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
                  '${streak.absentStreak}',
                  style: TextStyle(
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
                        AppStrings.absentSaturdays(streak.absentStreak),
                        if (lastPresent != null)
                          '${AppStrings.lastPresent} '
                              '${AppDateUtils.formatDate(lastPresent)}',
                      ].join(' • '),
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      followed
                          ? '✓ ${AppStrings.followedUpOn} '
                              '${AppDateUtils.formatDate(visit)}'
                          : AppStrings.notFollowedUp,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: followed ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              if (phone != null)
                IconButton(
                  tooltip: AppStrings.call,
                  icon: const Icon(Icons.call_rounded, size: 20),
                  color: AppColors.success,
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                ),
              IconButton(
                tooltip: AppStrings.markFollowedUp,
                icon: const Icon(Icons.task_alt_rounded, size: 22),
                color: AppColors.navy,
                onPressed: onFollowedUp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
