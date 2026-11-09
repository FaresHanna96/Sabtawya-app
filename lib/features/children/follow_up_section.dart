import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/reports.dart';
import 'child_profile_screen.dart';

enum StreakKind { absent, present }

/// A list of children by their run of Saturdays, longest first:
/// [StreakKind.absent] is "محتاجين متابعة" (missed 2 or more in a row) and
/// [StreakKind.present] is "ملتزمين" (attended 3 or more in a row). Hidden when
/// nobody qualifies.
class FollowUpSection extends StatelessWidget {
  const FollowUpSection({
    super.key,
    required this.streaks,
    this.showClass = false,
    this.onReturn,
    this.kind = StreakKind.absent,
    this.collapsible = false,
    this.initiallyExpanded = false,
    this.showWhenEmpty = false,
    this.bare = false,
  });

  /// Only the hint and the rows, no card around them (for [FollowUpTiles]).
  final bool bare;

  /// How many children qualify for [kind] (2+ absences / 3+ attendances).
  static int countFor(List<ChildStreak> streaks, StreakKind kind) => streaks
      .where((s) => kind == StreakKind.absent
          ? s.absentStreak >= 2
          : s.presentStreak >= 3)
      .length;

  /// Show the card with a short "nobody yet" line instead of hiding it, so an
  /// empty list is not mistaken for a missing feature.
  final bool showWhenEmpty;

  final List<ChildStreak> streaks;
  final StreakKind kind;

  bool get _isAbsent => kind == StreakKind.absent;
  int _run(ChildStreak s) => _isAbsent ? s.absentStreak : s.presentStreak;
  Color get _color => _isAbsent ? AppColors.coral : AppColors.success;
  IconData get _icon => _isAbsent
      ? Icons.support_agent_rounded
      : Icons.local_fire_department_rounded;
  String get _title =>
      _isAbsent ? AppStrings.needFollowUp : AppStrings.committedStreak;
  String get _hint =>
      _isAbsent ? AppStrings.needFollowUpHint : AppStrings.committedStreakHint;
  String get _label =>
      _isAbsent ? AppStrings.absentInARow : AppStrings.presentInARow;

  /// Show the class name too, for lists that span several classes.
  final bool showClass;

  /// Called after the profile screen closes, so the list can refresh.
  final VoidCallback? onReturn;

  /// Lets the user fold the list away under its title (the title keeps the
  /// count, so a folded list still says how many need following up).
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final absent = streaks.where((s) => _run(s) >= (_isAbsent ? 2 : 3)).toList()
      ..sort((a, b) {
        final byRun = _run(b).compareTo(_run(a));
        return byRun != 0 ? byRun : a.childName.compareTo(b.childName);
      });
    if (absent.isEmpty && !showWhenEmpty) return const SizedBox.shrink();

    final rows = <Widget>[
      Text(
        absent.isEmpty
            ? (_isAbsent ? AppStrings.noFollowUpNow : AppStrings.noCommittedYet)
            : _hint,
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      const SizedBox(height: 6),
      for (final s in absent) _row(context, s),
    ];

    if (bare) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    }

    if (collapsible) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: initiallyExpanded,
              leading: Icon(_icon, color: _color),
              title: Text(
                '$_title (${absent.length})',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SectionCard(
        title: '$_title (${absent.length})',
        icon: _icon,
        accent: _color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }

  Widget _row(BuildContext context, ChildStreak s) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ChildProfileScreen(childId: s.childId),
          ),
        );
        onReturn?.call();
      },
      title: Text(
        s.childName,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: showClass ? Text(s.className) : null,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$_label ${_run(s)} ${AppStrings.timesInARow}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _color,
          ),
        ),
      ),
    );
  }
}

/// "محتاجين متابعة" and "ملتزمين" side by side as two tiles with their counts.
/// Tapping a tile slides its list open under them; tapping it again (or the
/// other tile) closes or swaps it. Takes far less room than two stacked cards
/// and the counts are visible at a glance.
class FollowUpTiles extends StatefulWidget {
  const FollowUpTiles({super.key, required this.streaks, this.onReturn});

  final List<ChildStreak> streaks;
  final VoidCallback? onReturn;

  @override
  State<FollowUpTiles> createState() => _FollowUpTilesState();
}

class _FollowUpTilesState extends State<FollowUpTiles> {
  StreakKind? _open;

  void _toggle(StreakKind kind) =>
      setState(() => _open = _open == kind ? null : kind);

  @override
  Widget build(BuildContext context) {
    final open = _open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _tile(StreakKind.absent)),
            const SizedBox(width: 10),
            Expanded(child: _tile(StreakKind.present)),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: FollowUpSection(
                          key: ValueKey(open),
                          streaks: widget.streaks,
                          kind: open,
                          onReturn: widget.onReturn,
                          showWhenEmpty: true,
                          bare: true,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tile(StreakKind kind) {
    final absent = kind == StreakKind.absent;
    final color = absent ? AppColors.coral : AppColors.success;
    final count = FollowUpSection.countFor(widget.streaks, kind);
    final selected = _open == kind;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.12)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? color.withValues(alpha: 0.6) : Colors.transparent,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _toggle(kind),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    absent
                        ? Icons.support_agent_rounded
                        : Icons.local_fire_department_rounded,
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: count),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Text(
                          '$v',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: count == 0 ? AppColors.muted : color,
                          ),
                        ),
                      ),
                      Text(
                        absent
                            ? AppStrings.needFollowUp
                            : AppStrings.committedStreak,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: selected ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_more,
                    size: 20,
                    color: AppColors.muted,
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
