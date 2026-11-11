import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/visit_merge.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../data/models/child.dart';
import '../../data/models/reports.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import '../children/child_profile_screen.dart';

/// One child who missed two or more Saturdays in a row.
class _Row {
  const _Row(this.streak, this.child, this.contacted);

  final ChildStreak streak;
  final Child child;
  final bool contacted;
}

/// "محتاجين افتقاد" on the home page: children absent 2+ Saturdays in a row,
/// not-yet-contacted first. Tapping a row opens the profile to record the
/// visit; once saved, the row gets a "تم الافتقاد" mark.
class FollowUpTodo extends StatefulWidget {
  const FollowUpTodo({super.key});

  @override
  State<FollowUpTodo> createState() => _FollowUpTodoState();
}

class _FollowUpTodoState extends State<FollowUpTodo> {
  static const _reports = ReportRepository();
  static const _children = ChildRepository();
  static const _shown = 5;

  late Future<List<_Row>> _future = _load();
  bool _expanded = false;

  Future<List<_Row>> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return const [];
    final results = await Future.wait([
      _reports.streaks(yearId: yearId, minAbsent: 2, minPresent: 100000),
      _children.all(),
    ]);
    final streaks = results[0] as List<ChildStreak>;
    final byId = {for (final c in results[1] as List<Child>) c.id: c};

    final rows = <_Row>[
      for (final s in streaks)
        if (s.absentStreak >= 2 && byId[s.childId] != null)
          _Row(
            s,
            byId[s.childId]!,
            VisitMerge.contactedSince(byId[s.childId]!, s.lastPresentDate),
          ),
    ];
    rows.sort((a, b) {
      if (a.contacted != b.contacted) return a.contacted ? 1 : -1;
      final byRun = b.streak.absentStreak.compareTo(a.streak.absentStreak);
      return byRun != 0
          ? byRun
          : a.child.fullName.compareTo(b.child.fullName);
    });
    return rows;
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final showClass = session.isAdmin ||
        session.isGeneralServant ||
        session.myClasses.length > 1;

    return FutureBuilder<List<_Row>>(
      future: _future,
      builder: (context, snapshot) {
        // Nothing until the first answer (or on an error), so the home page
        // never flashes an empty or broken card.
        if (!snapshot.hasData) return const SizedBox.shrink();
        final rows = snapshot.data!;
        final open = rows.where((r) => !r.contacted).length;
        final visible = _expanded ? rows : rows.take(_shown).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SectionCard(
            title: rows.isEmpty
                ? AppStrings.followUpTodo
                : '${AppStrings.followUpTodo} ($open/${rows.length})',
            icon: Icons.support_agent_rounded,
            accent: AppColors.coral,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  rows.isEmpty
                      ? AppStrings.noFollowUpNow
                      : open == 0
                          ? AppStrings.followUpAllDone
                          : AppStrings.followUpTodoHint,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                if (rows.isNotEmpty) const SizedBox(height: 6),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      for (final (i, r) in visible.indexed)
                        staggered(i, _row(r, showClass)),
                    ],
                  ),
                ),
                if (rows.length > _shown)
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded
                          ? AppStrings.followUpShowLess
                          : AppStrings.followUpShowAll(rows.length),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(_Row r, bool showClass) {
    final color = r.contacted ? AppColors.success : AppColors.coral;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ChildProfileScreen(childId: r.child.id),
          ),
        );
        if (mounted) _reload();
      },
      title: Text(
        r.child.fullName,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          if (showClass) r.streak.className,
          r.contacted
              ? '✓ ${AppStrings.followUpDone}'
              : AppStrings.absentTimes(r.streak.absentStreak),
        ].join(' • '),
        style: TextStyle(fontSize: 12, color: color),
      ),
      trailing: Icon(
        r.contacted ? Icons.check_circle_rounded : Icons.chevron_left,
        color: r.contacted ? AppColors.success : AppColors.muted,
        size: 20,
      ),
    );
  }
}
