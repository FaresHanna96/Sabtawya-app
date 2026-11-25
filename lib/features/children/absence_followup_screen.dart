import 'package:flutter/material.dart';
import '../../core/utils/phone.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/class_filter_chips.dart';
import '../../core/widgets/class_group_header.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/whatsapp_icon.dart';
import '../../data/models/child.dart';
import '../../data/models/reports.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import 'child_profile_screen.dart';
import 'declining_attendance_screen.dart';
import 'follow_up_call.dart';

/// متابعة الغياب: children absent 2, 3 or 4+ Saturdays in a row, grouped by
/// class, worst first, with a call button and "تم الافتقاد", which records a
/// phone or home visit in the child's visit history.
class AbsenceFollowUpScreen extends StatefulWidget {
  const AbsenceFollowUpScreen({super.key, this.initialClassIds = const <String>{}});

  /// Opened from a class page: only that class to begin with (empty = all).
  final Set<String> initialClassIds;

  /// Whether a run of [run] Saturdays belongs to chip [n]: each chip holds
  /// only its own number, the last one holds that number and more.
  static bool inChip(int run, int n) => n >= 4 ? run >= 4 : run == n;

  @override
  State<AbsenceFollowUpScreen> createState() => _AbsenceFollowUpScreenState();
}

class _AbsenceFollowUpScreenState extends State<AbsenceFollowUpScreen> {
  @override
  void initState() {
    super.initState();
    _classIds = {...widget.initialClassIds};
  }

  static const _reports = ReportRepository();
  static const _children = ChildRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_Data>>();

  /// The chip shown: exactly 2 or 3 Saturdays in a row, or 4 = "4 or more".
  int _min = 2;
  Set<String> _classIds = <String>{};

  Future<_Data> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return const _Data([], {});
    final (streaks, children) = await (
      _reports.streaks(yearId: yearId, minAbsent: 2, minPresent: 999),
      _children.all(includeInactive: false),
    ).wait;
    final data = _Data(
      streaks.where((s) => s.absentStreak >= 2).toList(),
      {for (final c in children) c.id: c},
    );
    _openOnBusiestChip(data.streaks);
    return data;
  }

  bool _picked = false;

  /// Opened for one class (from its page): start on the chip holding most of
  /// that class's children instead of an empty or near-empty one.
  void _openOnBusiestChip(List<ChildStreak> streaks) {
    if (_picked || widget.initialClassIds.isEmpty) return;
    _picked = true;
    var best = _min;
    var bestCount = -1;
    for (final n in const [2, 3, 4]) {
      final count = streaks
          .where((s) =>
              AbsenceFollowUpScreen.inChip(s.absentStreak, n) &&
              widget.initialClassIds.contains(s.classId))
          .length;
      if (count > bestCount) {
        best = n;
        bestCount = count;
      }
    }
    _min = best;
  }

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _markFollowedUp(ChildStreak s, Child? child) async {
    final saved = await logFollowUp(
      context,
      childId: s.childId,
      childName: s.childName,
      absentStreak: s.absentStreak,
      child: child,
    );
    if (saved) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<SessionController>().myClasses;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.absenceFollowUp),
        actions: [
          IconButton(
            tooltip: AppStrings.decliningAttendance,
            icon: const Icon(Icons.trending_down_rounded),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const DecliningAttendanceScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AsyncSection<_Data>(
          key: _sectionKey,
          load: _load,
          loading: const SkeletonList(),
          builder: (context, data, _) {
            final rows = data.streaks
                .where((s) =>
                    AbsenceFollowUpScreen.inChip(s.absentStreak, _min) &&
                    (_classIds.isEmpty || _classIds.contains(s.classId)))
                .toList()
              ..sort((a, b) {
                // Followed up ones sink to the bottom, worst streak first.
                final fa = isFollowedUp(a, data.children[a.childId]);
                final fb = isFollowedUp(b, data.children[b.childId]);
                if (fa != fb) return fa ? 1 : -1;
                return b.absentStreak.compareTo(a.absentStreak);
              });
            final followedCount = rows
                .where((s) => isFollowedUp(s, data.children[s.childId]))
                .length;
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
                                    AbsenceFollowUpScreen.inChip(
                                        s.absentStreak, n) &&
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
                if (rows.isNotEmpty)
                  FollowUpProgressStrip(done: followedCount, total: rows.length),
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

/// The last phone or home visit of [child], whichever is newer.
DateTime? lastVisitOf(Child? child) {
  final a = child?.lastPhoneVisitDate;
  final b = child?.lastHomeVisitDate;
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

/// Followed up already: someone visited after the last time they came.
@visibleForTesting
bool isFollowedUp(ChildStreak s, Child? child) {
  final visit = lastVisitOf(child);
  final lastPresent = s.lastPresentDate;
  return visit != null && (lastPresent == null || !visit.isBefore(lastPresent));
}

/// "اتفتقد 2 من 4 النهارده" with a bar that fills as cards are done.
@visibleForTesting
class FollowUpProgressStrip extends StatelessWidget {
  const FollowUpProgressStrip(
      {super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : done / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.followedUpProgress(done, total),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: ratio),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 7,
                color: AppColors.success,
                backgroundColor: AppColors.navy.withValues(alpha: 0.08),
              ),
            ),
          ),
        ],
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

  DateTime? get _lastVisit => lastVisitOf(child);

  String? get _phone => callNumberFor(child);

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
    final whatsapp = WhatsApp.numberFor(child);

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
                    color: AppColors.readable(color),
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
                  onPressed: () => callNumber(phone),
                ),
              if (whatsapp != null)
                IconButton(
                  tooltip: AppStrings.whatsapp,
                  icon: const WhatsAppIcon(size: 22),
                  onPressed: () => launchUrl(
                    WhatsApp.link(
                      whatsapp,
                      WhatsApp.absenceMessage(
                        childName: streak.childName,
                        servantName:
                            context.read<SessionController>().displayName,
                        absent: streak.absentStreak,
                      ),
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
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
