import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/motion.dart';
import '../../data/models/badges.dart';
import 'badge_look.dart';

/// النقاط والأوسمة on a child's profile: the game points with the growth
/// level, the run of Saturdays, the place in the class, then the six badges
/// (tap one for its rule, and when it was won or how far along it is).
class ChildBadgesCard extends StatefulWidget {
  const ChildBadgesCard({
    super.key,
    required this.badges,
    required this.gamePoints,
    this.rank,
    this.onOpenRanking,
    this.showPoints = true,
    this.detailInSheet = false,
  });

  final List<ChildBadge> badges;

  /// False when the points sit elsewhere (the profile's header): only the
  /// badges are drawn.
  final bool showPoints;

  /// Tapping a badge opens its rule and progress in a sheet instead of a box
  /// under the grid (keeps the card to the grid alone).
  final bool detailInSheet;

  /// Attendance points this year + [kBadgeBonus] per badge.
  final int gamePoints;

  /// Place in the class (null when not known).
  final int? rank;
  final VoidCallback? onOpenRanking;

  @override
  State<ChildBadgesCard> createState() => _ChildBadgesCardState();
}

class _ChildBadgesCardState extends State<ChildBadgesCard> {
  KidBadge? _picked;

  List<ChildBadge> get _ordered => [
        for (final b in KidBadge.values)
          for (final cb in widget.badges)
            if (cb.badge == b) cb,
      ];

  @override
  Widget build(BuildContext context) {
    final badges = _ordered;
    final earned = badges.where((b) => b.earned).length;
    final run = currentRun(badges);
    final selected = badges.isEmpty
        ? null
        : badges.firstWhere(
            (b) => b.badge == (_picked ?? badges.first.badge),
            orElse: () => badges.first,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showPoints) ...[
          GamePointsPanel(
            points: widget.gamePoints,
            run: run,
            rank: widget.rank,
            onOpenRanking: widget.onOpenRanking,
          ),
          const SizedBox(height: 12),
        ],
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        AppStrings.badgesTitle,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      AppStrings.badgesOf(earned, badges.length),
                      style:
                          const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                  children: [
                    for (final b in badges)
                      _BadgeTile(
                        badge: b,
                        selected:
                            !widget.detailInSheet && b.badge == selected?.badge,
                        onTap: () {
                          Haptics.select();
                          if (widget.detailInSheet) {
                            showModalBottomSheet<void>(
                              context: context,
                              showDragHandle: true,
                              builder: (_) => SafeArea(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      BadgeMedal(
                                        badge: b.badge,
                                        earned: b.earned,
                                        size: 72,
                                      ),
                                      const SizedBox(height: 12),
                                      _BadgeDetail(badge: b),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          } else {
                            setState(() => _picked = b.badge);
                          }
                        },
                      ),
                  ],
                ),
                if (selected != null && !widget.detailInSheet) ...[
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _BadgeDetail(
                      key: ValueKey(selected.badge),
                      badge: selected,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The Saturdays in a row still going: the long-streak badge carries it,
/// uncapped up to 12.
int currentRun(List<ChildBadge> badges) => badges
    .where((b) => b.badge == KidBadge.streak16)
    .map((b) => b.progress)
    .fold(0, (a, b) => b > a ? b : a);

/// The game points on navy: the points and the level, the bar to the next
/// level, the run of Saturdays and the place in the class. [framed] draws its
/// own navy card; false lays it on a navy card already there (the profile's
/// header).
class GamePointsPanel extends StatelessWidget {
  const GamePointsPanel({
    super.key,
    required this.points,
    required this.run,
    this.rank,
    this.onOpenRanking,
    this.framed = true,
    this.attendancePct,
    this.onOpenAttendance,
  });

  final int points;
  final int run;
  final int? rank;
  final VoidCallback? onOpenRanking;
  final bool framed;

  /// The year's attendance %, as a third chip (the profile's header); none
  /// when null.
  final double? attendancePct;
  final VoidCallback? onOpenAttendance;

  @override
  Widget build(BuildContext context) {
    final level = GameLevel.of(points);
    final next = level.next;
    const soft = Color(0xFFDCE4F2);
    return Container(
      padding: framed ? const EdgeInsets.all(16) : EdgeInsets.zero,
      decoration: framed
          ? BoxDecoration(
              gradient: AppGradients.navyHeader,
              borderRadius: BorderRadius.circular(20),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(AppStrings.gamePointsLabel,
                        style: TextStyle(fontSize: 12.5, color: soft)),
                    // Shrinks rather than overflows next to the level chip.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          AnimatedCount(
                            value: points,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(AppStrings.pointsWord,
                              style: TextStyle(fontSize: 13, color: soft)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Tap: the four levels and where this child stands.
              Material(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Haptics.select();
                    showLevelsSheet(context, points);
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(level.icon, size: 18, color: AppColors.oliveLight),
                        const SizedBox(width: 6),
                        Text(
                          level.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.expand_more_rounded,
                            size: 18, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: GameLevel.progress(points)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation(AppColors.oliveLight),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            next == null
                ? AppStrings.topLevelReached
                : AppStrings.toNextLevel(GameLevel.toNext(points), next.title),
            style: const TextStyle(fontSize: 12, color: soft),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (attendancePct != null) ...[
                Expanded(
                  child: _Chip(
                    icon: Icons.fact_check_rounded,
                    value: '${attendancePct!.round()}%',
                    label: AppStrings.attendanceChip,
                    onTap: onOpenAttendance,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _Chip(
                  icon: Icons.local_fire_department_rounded,
                  value: AppStrings.saturdaysInARow(run),
                  label: AppStrings.inARow,
                ),
              ),
              if (rank != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _Chip(
                    icon: Icons.emoji_events_rounded,
                    value: AppStrings.rankInClass(rank!),
                    label: AppStrings.inClassLink,
                    onTap: onOpenRanking,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFF2C46D)),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFDCE4F2)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final ChildBadge badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: badge.badge.title,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected
                ? AppColors.navy
                : AppColors.navy.withValues(alpha: 0.08),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BadgeMedal(badge: badge.badge, earned: badge.earned),
                const SizedBox(height: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      badge.badge.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: badge.earned ? AppColors.navy : AppColors.muted,
                      ),
                    ),
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

class _BadgeDetail extends StatelessWidget {
  const _BadgeDetail({super.key, required this.badge});

  final ChildBadge badge;

  @override
  Widget build(BuildContext context) {
    final earned = badge.earned;
    final stateColor = earned ? AppColors.success : AppColors.muted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wraps under the title when the date does not fit beside it.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                badge.badge.title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: statusTint(stateColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  earned
                      ? AppStrings.earnedOnDay(
                          AppDateUtils.formatDate(badge.earnedOn!))
                      : AppStrings.notYet,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.readable(stateColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            badge.badge.rule,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          if (!earned) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: badge.share,
                      minHeight: 6,
                      backgroundColor: AppColors.navy.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation(AppColors.navy),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppStrings.progressOf(badge.progress, badge.target),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The growth levels, from the level chip: each with the points it starts
/// at, the child's own highlighted, the ones behind ticked, and how many
/// points the next one still needs.
Future<void> showLevelsSheet(BuildContext context, int points) {
  final current = GameLevel.of(points);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Taller than the default when the text is large; scrolls if needed.
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                AppStrings.levelsTitle,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                AppStrings.levelsHint,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              for (final l in GameLevel.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LevelRow(level: l, points: points, current: current),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One level in the sheet.
@visibleForTesting
class LevelRow extends StatelessWidget {
  const LevelRow({
    super.key,
    required this.level,
    required this.points,
    required this.current,
  });

  final GameLevel level;
  final int points;
  final GameLevel current;

  @override
  Widget build(BuildContext context) {
    final isCurrent = level == current;
    final reached = points >= level.from;
    final color = reached ? AppColors.olive : AppColors.muted;
    final String status;
    if (isCurrent) {
      status = AppStrings.levelYouAreHere;
    } else if (reached) {
      status = AppStrings.levelReached;
    } else {
      status = AppStrings.levelPointsLeft(level.from - points);
    }
    return Semantics(
      selected: isCurrent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.oliveTint : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent
                ? AppColors.olive
                : AppColors.navy.withValues(alpha: 0.08),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusTint(color, 0.14),
              ),
              child: Icon(level.icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: reached ? AppColors.navy : AppColors.muted,
                    ),
                  ),
                  Text(
                    AppStrings.levelFrom(level.from),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (reached && !isCurrent)
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.success)
            else
              const SizedBox.shrink(),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isCurrent
                    ? AppColors.oliveText
                    : (reached ? AppColors.success : AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
