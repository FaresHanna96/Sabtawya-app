import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/class_health.dart';
import '../classes/class_detail_screen.dart';

/// صحة الفصول on أمين الخدمة's home, made to be read at a glance:
/// a summary strip (how many classes are fine, to follow, need support), then
/// one tile per class that needs something, its problems as small chips with
/// icons, and the classes doing well folded into one line. Tapping a class
/// shows its numbers as bars and the way to its page.
class ClassHealthSection extends StatefulWidget {
  const ClassHealthSection({super.key, required this.classes});

  final List<ClassHealth> classes;

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

  static IconData levelIcon(HealthLevel level) => switch (level) {
        HealthLevel.red => Icons.priority_high_rounded,
        HealthLevel.amber => Icons.visibility_outlined,
        HealthLevel.green => Icons.check_rounded,
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
  /// The tiles shown before "عرض الكل".
  static const _shownAtFirst = 4;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.classes]..sort(ClassHealth.byConcern);
    final needy = sorted.where((c) => c.level != HealthLevel.green).toList();
    final good = sorted.where((c) => c.level == HealthLevel.green).toList();
    final red = needy.where((c) => c.level == HealthLevel.red).length;
    final amber = needy.length - red;
    final shown =
        _showAll ? needy : needy.take(_shownAtFirst).toList(growable: false);

    return SectionCard(
      title: AppStrings.classHealthTitle,
      icon: Icons.monitor_heart_outlined,
      accent: needy.isEmpty ? AppColors.success : AppColors.coral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // At a glance: three counts.
          Row(
            children: [
              _CountPill(level: HealthLevel.green, count: good.length),
              const SizedBox(width: 8),
              _CountPill(level: HealthLevel.amber, count: amber),
              const SizedBox(width: 8),
              _CountPill(level: HealthLevel.red, count: red),
            ],
          ),
          const SizedBox(height: 12),
          if (needy.isEmpty)
            const _AllGood()
          else ...[
            for (final c in shown)
              _ClassTile(health: c, onTap: () => _details(context, c)),
            if (needy.length > _shownAtFirst)
              TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll
                      ? AppStrings.showLess
                      : AppStrings.showAllClasses(needy.length),
                ),
              ),
          ],
          if (good.isNotEmpty && needy.isNotEmpty) ...[
            const SizedBox(height: 4),
            _GoodLine(classes: good, onTap: (c) => _details(context, c)),
          ],
        ],
      ),
    );
  }

  Future<void> _details(BuildContext context, ClassHealth c) =>
      showModalBottomSheet<void>(
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

/// "3 تمام" with the level's color.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.level, required this.count});

  final HealthLevel level;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = ClassHealthSection.colorOf(level);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: count == 0 ? 0.04 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: count == 0 ? AppColors.muted : color,
              ),
            ),
            Text(
              ClassHealthSection.labelOf(level),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// One class that needs something: a colored edge, its name and status, and
/// what is wrong as chips.
class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.health, required this.onTap});

  final ClassHealth health;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ClassHealthSection.colorOf(health.level);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: BorderDirectional(
                start: BorderSide(color: color, width: 4),
              ),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        health.className,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _StatusBadge(level: health.level),
                    const Icon(AppIcons.forward,
                        size: 18, color: AppColors.muted),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in health.reasons) _ReasonChip(reason: r),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.level});

  final HealthLevel level;

  @override
  Widget build(BuildContext context) {
    final color = ClassHealthSection.colorOf(level);
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ClassHealthSection.levelIcon(level), size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            ClassHealthSection.labelOf(level),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// One problem: its icon and a short sentence, in its own color.
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});

  final HealthReason reason;

  @override
  Widget build(BuildContext context) {
    final color = ClassHealthSection.colorOf(reason.level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ClassHealthSection.areaIcon(reason.area), size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              reason.text,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// No class needs anything.
class _AllGood extends StatelessWidget {
  const _AllGood();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.celebration_rounded, color: AppColors.success),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.allClassesHealthy,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// "ماشيين كويس: 3 بنات، 4 ولاد" — each name opens its numbers.
class _GoodLine extends StatelessWidget {
  const _GoodLine({required this.classes, required this.onTap});

  final List<ClassHealth> classes;
  final ValueChanged<ClassHealth> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.check_circle_rounded,
            size: 16, color: AppColors.success),
        const Text(
          AppStrings.healthGoodClasses,
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        for (final c in classes)
          ActionChip(
            visualDensity: VisualDensity.compact,
            label: Text(c.className, style: const TextStyle(fontSize: 12)),
            onPressed: () => onTap(c),
          ),
      ],
    );
  }
}

/// All the numbers of one class, each as a labelled bar, and its page.
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
                Expanded(
                  child: Text(
                    c.className,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusBadge(level: c.level),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${AppStrings.healthServants}: ${c.servantsCount} • '
              '${AppStrings.healthChildren}: ${c.activeChildren}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            if (c.reasons.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final r in c.reasons) _ReasonChip(reason: r)],
              ),
              const SizedBox(height: 16),
            ],
            _Bar(
              icon: Icons.fact_check_outlined,
              label: AppStrings.healthTaken,
              value: AppStrings.outOf(c.taken, c.held),
              share: ClassHealth.share(c.taken, c.held),
              good: ClassHealth.takenAmber,
            ),
            _Bar(
              icon: Icons.menu_book_outlined,
              label: AppStrings.healthPrep,
              value: c.prepExpected == 0
                  ? '—'
                  : '${AppStrings.outOf(c.prepSubmitted, c.prepExpected)}'
                      ' • ${AppStrings.healthAccepted} ${c.prepAccepted}',
              share: ClassHealth.share(c.prepSubmitted, c.prepExpected),
              good: ClassHealth.prepAmber,
            ),
            _Bar(
              icon: Icons.phone_in_talk_outlined,
              label: AppStrings.healthFollowUp,
              value: c.absent2plus == 0
                  ? AppStrings.healthNoAbsent
                  : AppStrings.outOf(c.absentFollowed, c.absent2plus),
              share: c.absent2plus == 0
                  ? 1
                  : ClassHealth.share(c.absentFollowed, c.absent2plus),
              good: 1,
            ),
            _Bar(
              icon: Icons.groups_outlined,
              label: AppStrings.healthPresent,
              value: c.presentPct == null
                  ? '—'
                  : '${c.presentPct!.toStringAsFixed(0)}%',
              share: c.presentPct == null ? null : c.presentPct! / 100,
              good: ClassHealth.presentAmber / 100,
            ),
            if (c.takenLate > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 16, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(
                      '${AppStrings.healthLate}: ${c.takenLate}',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    c.level == HealthLevel.green ? null : color,
              ),
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

/// "التحضير المرفوع   6 من 14" over a bar, green at or above [good].
class _Bar extends StatelessWidget {
  const _Bar({
    required this.icon,
    required this.label,
    required this.value,
    required this.share,
    required this.good,
  });

  final IconData icon;
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
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
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
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
