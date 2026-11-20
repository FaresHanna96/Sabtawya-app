import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/class_health.dart';
import '../classes/class_detail_screen.dart';

/// صحة الفصول, kept light on the home page: one short line per class that
/// needs something (a colored dot, the name, its biggest problem), the few
/// worst first, and the classes doing well folded into one line. Everything
/// else is one tap away, in the class's sheet.
///
/// أمين الخدمة sees every class; a servant sees their own class(es) only (the
/// database decides which rows come back).
class ClassHealthSection extends StatefulWidget {
  const ClassHealthSection({
    super.key,
    required this.classes,
    this.title = AppStrings.classHealthTitle,
  });

  final List<ClassHealth> classes;
  final String title;

  static Color colorOf(HealthLevel level) => switch (level) {
        HealthLevel.red => AppColors.danger,
        HealthLevel.amber => AppColors.warning,
        HealthLevel.green => AppColors.success,
      };

  static String labelOf(HealthLevel level) => switch (level) {
        HealthLevel.red => AppStrings.healthNeedsSupport,
        HealthLevel.amber => AppStrings.healthToFollow,
        HealthLevel.green => AppStrings.healthGood,
      };

  static IconData areaIcon(HealthArea area) => switch (area) {
        HealthArea.servants => Icons.person_off_outlined,
        HealthArea.attendance => Icons.fact_check_outlined,
        HealthArea.late => Icons.schedule_rounded,
        HealthArea.prep => Icons.menu_book_outlined,
        HealthArea.followUp => Icons.phone_in_talk_outlined,
        HealthArea.presence => Icons.groups_outlined,
      };

  @override
  State<ClassHealthSection> createState() => _ClassHealthSectionState();
}

class _ClassHealthSectionState extends State<ClassHealthSection> {
  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.classes]..sort(ClassHealth.byConcern);
    final needy = sorted.where((c) => c.level != HealthLevel.green).length;

    return SectionCard(
      title: widget.title,
      icon: Icons.monitor_heart_outlined,
      accent: needy == 0 ? AppColors.success : AppColors.coral,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              needy == 0
                  ? AppStrings.allClassesHealthy
                  : AppStrings.healthScoreHint,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          for (final c in sorted) _Line(health: c, onTap: () => _open(c)),
        ],
      ),
    );
  }

  Future<void> _open(ClassHealth c) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => _DetailSheet(
          health: c,
          onOpenClass: () {
            Navigator.of(sheet).pop();
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ClassDetailScreen(classId: c.classId),
              ),
            );
          },
        ),
      );
}

/// "3 بنات ........ 62%" over a thin bar, and under it the one thing to fix
/// (only when the class is not green).
class _Line extends StatelessWidget {
  const _Line({required this.health, required this.onTap});

  final ClassHealth health;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ClassHealthSection.colorOf(health.level);
    final score = health.score;
    final reasons = health.reasons;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    health.className,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  score == null ? '—' : '$score%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(AppIcons.forward, size: 18, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (score ?? 0) / 100,
                minHeight: 6,
                color: color,
                backgroundColor: AppColors.muted.withValues(alpha: 0.12),
              ),
            ),
            if (health.level != HealthLevel.green && reasons.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                reasons.first.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A class's whole picture, on tap: what to look at, then each measure as a
/// bar, and its page.
class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.health, required this.onOpenClass});

  final ClassHealth health;
  final VoidCallback onOpenClass;

  @override
  Widget build(BuildContext context) {
    final c = health;
    final color = ClassHealthSection.colorOf(c.level);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.className,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  c.score == null
                      ? ClassHealthSection.labelOf(c.level)
                      : '${c.score}% • ${ClassHealthSection.labelOf(c.level)}',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${AppStrings.healthServants}: ${c.servantsCount} • '
              '${AppStrings.healthChildren}: ${c.activeChildren}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            for (final r in c.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(ClassHealthSection.areaIcon(r.area),
                        size: 16, color: ClassHealthSection.colorOf(r.level)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(r.text, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            if (c.reasons.isNotEmpty) const Divider(height: 24),
            _Bar(
              label: AppStrings.healthPresent,
              value: c.childrenAttendance == null
                  ? '—'
                  : '${c.childrenAttendance!.toStringAsFixed(0)}%',
              share: c.childrenAttendance == null
                  ? null
                  : c.childrenAttendance! / 100,
              good: ClassHealth.scoreGreen / 100,
            ),
            _Bar(
              label: AppStrings.healthTaken,
              value: AppStrings.outOf(c.taken, c.held),
              share: ClassHealth.share(c.taken, c.held),
              good: ClassHealth.takenAmber,
            ),
            _Bar(
              label: AppStrings.healthPrep,
              value: c.prepExpected == 0
                  ? '—'
                  : AppStrings.outOf(c.prepSubmitted, c.prepExpected),
              share: ClassHealth.share(c.prepSubmitted, c.prepExpected),
              good: ClassHealth.prepAmber,
            ),
            _Bar(
              label: AppStrings.healthFollowUp,
              value: c.absent2plus == 0
                  ? AppStrings.healthNoAbsent
                  : AppStrings.outOf(c.absentFollowed, c.absent2plus),
              share: c.absent2plus == 0
                  ? 1
                  : ClassHealth.share(c.absentFollowed, c.absent2plus),
              good: 1,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onOpenClass,
              icon: const Icon(Icons.class_outlined, size: 18),
              label: const Text(AppStrings.openClass),
            ),
          ],
        ),
      ),
    );
  }
}

/// "التحضير المرفوع   6 من 14" over a thin bar, green at or above [good].
class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.share,
    required this.good,
  });

  final String label;
  final String value;

  /// 0..1; null when there is nothing to measure yet.
  final double? share;
  final double good;

  @override
  Widget build(BuildContext context) {
    final s = share;
    final color = s == null
        ? AppColors.muted
        : s >= good
            ? AppColors.success
            : s >= good * 0.6
                ? AppColors.warning
                : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s ?? 0,
              minHeight: 5,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
