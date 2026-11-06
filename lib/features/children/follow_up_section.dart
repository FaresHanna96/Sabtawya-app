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
  });

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
    if (absent.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[
      Text(
        _hint,
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      const SizedBox(height: 6),
      for (final s in absent) _row(context, s),
    ];

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
