import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/child_changes.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/child.dart';

/// Who added or edited the child and who recorded their attendance, as a
/// timeline: one heading per day, then who did what and at what time. Same-day
/// entries by the same person are one line; the latest five show first.
class ChangeHistoryCard extends StatefulWidget {
  const ChangeHistoryCard({
    super.key,
    required this.changes,
    this.now,
    this.onUndo,
  });

  /// Newest first, as the database returns them.
  final List<ChildChange> changes;

  /// Only for tests; the real card reads the clock.
  final DateTime? now;

  /// Called with the line to undo; null hides the button (for people who
  /// may not edit the child).
  final Future<void> Function(ChildChangeGroup group)? onUndo;

  @override
  State<ChangeHistoryCard> createState() => _ChangeHistoryCardState();
}

class _ChangeHistoryCardState extends State<ChangeHistoryCard> {
  static const _initialCount = 5;

  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final groups = groupChanges(widget.changes);
    final shown = _showAll ? groups : groups.take(_initialCount).toList();

    final rows = <Widget>[];
    for (var i = 0; i < shown.length; i++) {
      final day = shown[i].latest.toLocal();
      final newDay = i == 0 ||
          !AppDateUtils.isSameDay(shown[i - 1].latest.toLocal(), day);
      final endsDay = i == shown.length - 1 ||
          !AppDateUtils.isSameDay(shown[i + 1].latest.toLocal(), day);
      if (newDay) rows.add(_dayHeader(day, first: i == 0));
      rows.add(_ChangeRow(
        group: shown[i],
        connect: !endsDay,
        onUndo: widget.onUndo,
      ));
    }

    return SectionCard(
      title: AppStrings.changeHistory,
      icon: Icons.history_rounded,
      accent: AppColors.navy,
      collapsible: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...rows,
          if (groups.length > _initialCount)
            TextButton.icon(
              onPressed: () => setState(() => _showAll = !_showAll),
              icon: Icon(
                _showAll ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(_showAll
                  ? AppStrings.showLess
                  : AppStrings.showAllCount(groups.length)),
            ),
        ],
      ),
    );
  }

  /// "اليوم", "أمس", or "الجمعة 13 نوفمبر · منذ 3 أيام".
  Widget _dayHeader(DateTime day, {required bool first}) {
    final now = widget.now ?? DateTime.now();
    final recent = AppDateUtils.daysBetween(day, now) < 2;
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 10, bottom: 8),
      child: Row(
        children: [
          Text(
            AppDateUtils.dayLabel(day, now: now),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          if (!recent) ...[
            const SizedBox(width: 6),
            Text(
              '· ${AppDateUtils.sinceLabel(day, now: now)}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              height: 1,
              color: AppColors.muted.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.group,
    required this.connect,
    this.onUndo,
  });

  final ChildChangeGroup group;
  final Future<void> Function(ChildChangeGroup group)? onUndo;

  /// Draw the line down to the next entry of the same day.
  final bool connect;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final (IconData icon, Color color, String what) = g.isAttendance
        ? (Icons.fact_check_rounded, AppColors.sky, AppStrings.changeAttendance)
        : g.isAdded
            ? (
                Icons.person_add_alt_1_rounded,
                AppColors.success,
                AppStrings.changeAdded
              )
            : (Icons.edit_rounded, AppColors.navyLight, AppStrings.changeEdited);
    final labels = g.labels;
    final details = g.descriptions;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              if (connect)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.muted.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          g.by,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: g.hasActor ? null : AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          AppDateUtils.formatTime(g.latest),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    what,
                    style:
                        const TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final d in details) _detail(d),
                  ] else if (labels.isNotEmpty) ...[
                    // Older entries only know which fields, not the values.
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final l in labels) _chip(l)],
                    ),
                  ],
                  if (g.canUndo && onUndo != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => onUndo!(g),
                        icon: const Icon(Icons.undo_rounded, size: 16),
                        label: const Text(AppStrings.undo),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "العنوان: من «قديم» إلى «جديد»", the field name picked out.
  Widget _detail(FieldChangeText d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.navyTint.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text.rich(
          TextSpan(
            text: '${d.label}: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
            children: [
              TextSpan(
                text: d.text,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.navyTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          color: AppColors.navy,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
