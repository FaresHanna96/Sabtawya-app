import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/servant_activity.dart';

/// The four activities a servant is marked for on a Saturday (the prep is
/// its own slot), in the order the row shows them.
const servantDayActivities = <String>[
  'sunday_school',
  'servant_meeting',
  'mass',
  'confession',
];

/// How far the Saturday's servant attendance has got.
class ServantDayProgress {
  const ServantDayProgress({
    required this.marked,
    required this.total,
    required this.pendingPreps,
  });

  /// Servants with at least one of the four activities marked.
  final int marked;
  final int total;

  /// Preps sent for this Saturday still waiting for the admin's review.
  final int pendingPreps;

  double get share => total == 0 ? 0 : marked / total;

  /// [isMarked] says whether a servant has a mark in an activity.
  static ServantDayProgress of({
    required List<String> servantIds,
    required bool Function(String servantId, String type) isMarked,
    required List<LessonPrep> preps,
  }) {
    var marked = 0;
    for (final id in servantIds) {
      if (servantDayActivities.any((t) => isMarked(id, t))) marked++;
    }
    return ServantDayProgress(
      marked: marked,
      total: servantIds.length,
      pendingPreps: preps.where((p) => p.isPending).length,
    );
  }
}

/// «اتسجّل 12 من 18 خادم • 3 تحضيرات مستنية مراجعة» with a bar.
class ServantDayProgressLine extends StatelessWidget {
  const ServantDayProgressLine({super.key, required this.progress});

  final ServantDayProgress progress;

  @override
  Widget build(BuildContext context) {
    final done = progress.total > 0 && progress.marked == progress.total;
    final color = done ? AppColors.success : AppColors.navy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.servantsMarkedOf(progress.marked, progress.total),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.readable(color),
                ),
              ),
            ),
            if (progress.pendingPreps > 0)
              Text(
                AppStrings.prepsWaitingReview(progress.pendingPreps),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warningText,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress.share),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: AppColors.navy.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(
                  done ? AppColors.success : AppColors.navy),
            ),
          ),
        ),
      ],
    );
  }
}

/// One slot of a servant's row: a round icon over a short label. Present is
/// green with a tick; [busy] shows while its save is on its way.
class ServantSlot extends StatelessWidget {
  const ServantSlot({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.on,
    required this.onTap,
    this.busy = false,
    this.semantics,
  });

  final String label;
  final IconData icon;

  /// The slot's colour when on (green for an activity; the prep's status
  /// colour for تحضير).
  final Color color;
  final bool on;
  final bool busy;
  final VoidCallback onTap;

  /// Read aloud instead of [label] (the prep says its status too).
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final tint = on ? color : AppColors.muted;
    return Semantics(
      button: true,
      toggled: on,
      label: semantics ?? label,
      excludeSemantics: true,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                width: 38,
                height: 38,
                transform:
                    Matrix4.diagonal3Values(on ? 1.06 : 1, on ? 1.06 : 1, 1),
                transformAlignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on
                      ? statusTint(color, 0.16)
                      : AppColors.muted.withValues(alpha: 0.08),
                  border: Border.all(
                    color: tint.withValues(alpha: on ? 0.6 : 0.25),
                    width: 1.4,
                  ),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, size: 18, color: tint),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.readable(tint),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One servant on «حضور الخدام»: the name with their class (a tap opens
/// their page), then the five slots in one row of equal width, so nothing
/// wraps onto a line of its own.
class ServantDayRow extends StatelessWidget {
  const ServantDayRow({
    super.key,
    required this.name,
    required this.className,
    required this.slots,
    required this.onOpen,
  });

  final String name;

  /// The class they serve; null for a general servant.
  final String? className;

  /// Five [ServantSlot]s: تحضير, خدمة, اجتماع, قداس, اعتراف.
  final List<Widget> slots;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '  •  ${className ?? AppStrings.generalServantShort}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(AppIcons.forward,
                        size: 18, color: AppColors.muted),
                  ],
                ),
              ),
            ),
            Row(
              children: [for (final s in slots) Expanded(child: s)],
            ),
          ],
        ),
      ),
    );
  }
}
