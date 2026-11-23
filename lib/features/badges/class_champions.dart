import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/child.dart';
import '../../data/models/reports.dart';
import '../../data/repositories/badge_repository.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import '../children/child_avatar.dart';

/// «🔥 5»: a child's current run of Saturdays, from 3 up; nothing below that.
/// The flame pulses for a run of 5 or more.
@visibleForTesting
class RunBadge extends StatelessWidget {
  const RunBadge({super.key, required this.run, this.leading = false});

  final int run;

  /// In a row after other text: a small gap before it.
  final bool leading;

  @override
  Widget build(BuildContext context) {
    if (run < 3) return const SizedBox.shrink();
    const flame = Icon(Icons.local_fire_department_rounded,
        size: 15, color: AppColors.coral);
    return Padding(
      padding: EdgeInsetsDirectional.only(start: leading ? 8 : 0, top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          run >= 5 ? const Pulse(child: flame) : flame,
          const SizedBox(width: 2),
          Text(
            '$run',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.coralText,
            ),
          ),
        ],
      ),
    );
  }
}

/// The tier a run of Saturdays has reached, and what is left for the next.
class ChampionTier {
  const ChampionTier._();

  /// على الطريق (3), ملتزم (4–15) or ملتزم ذهبي (16+).
  static (String, Color) of(int run) {
    if (run >= 16) return (AppStrings.tierGold, AppColors.gold);
    if (run >= 4) return (AppStrings.tierCommitted, AppColors.success);
    return (AppStrings.committedTierNear, AppColors.sky);
  }

  /// What the run is still short of: the «ملتزم» badge below 4, «ملتزم
  /// ذهبي» from 4 to 15; null once it is gold.
  static String? nextGoal(int run) {
    if (run < 4) return AppStrings.oneLeftForCommitted;
    if (run < 16) return AppStrings.leftForGold(16 - run);
    return null;
  }
}

/// «أبطال الالتزام» on a class page: the first three on a run, and «عرض الكل».
class ClassChampionsCard extends StatelessWidget {
  const ClassChampionsCard({
    super.key,
    required this.champions,
    required this.onSeeAll,
    this.points = const {},
  });

  /// The children on a run of 3 or more, in order ([championsOf]).
  final List<ChildStreak> champions;
  final VoidCallback onSeeAll;

  /// childId -> game points, shown next to the run.
  final Map<String, int> points;

  /// The children of [streaks] on a run of 3 or more: the longest run of
  /// Saturdays first, then the most [points] (childId -> game points), then
  /// by name.
  static List<ChildStreak> championsOf(
    Iterable<ChildStreak> streaks, {
    Map<String, int> points = const {},
  }) =>
      [
        for (final s in streaks)
          if (s.presentStreak >= 3) s,
      ]..sort((a, b) {
          final byRun = b.presentStreak.compareTo(a.presentStreak);
          if (byRun != 0) return byRun;
          final byPoints =
              (points[b.childId] ?? 0).compareTo(points[a.childId] ?? 0);
          return byPoints != 0 ? byPoints : a.childName.compareTo(b.childName);
        });

  @override
  Widget build(BuildContext context) {
    final top = champions.take(3).toList();
    return SectionCard(
      title: AppStrings.championsTitle,
      icon: Icons.local_fire_department_rounded,
      accent: AppColors.coral,
      trailing: TextButton(
        onPressed: onSeeAll,
        child: Text(
          champions.length > 3
              ? '${AppStrings.seeAll} (${champions.length})'
              : AppStrings.seeAll,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          for (final s in top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  _Initial(name: s.childName, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.childName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _TierPill(run: s.presentStreak),
                  const SizedBox(width: 8),
                  RunBadge(run: s.presentStreak),
                  if (points[s.childId] != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      AppStrings.pointsOf(points[s.childId]!),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// «أبطال الالتزام» for one class, opened from its page.
class ClassChampionsScreen extends StatelessWidget {
  const ClassChampionsScreen({
    super.key,
    required this.classId,
    required this.className,
    this.load,
  });

  final String classId;
  final String className;

  /// Replaces the real read; tests give their own.
  final Future<(List<ChildStreak>, Map<String, Child>, Map<String, int>)>
      Function()? load;

  Future<(List<ChildStreak>, Map<String, Child>, Map<String, int>)> _load(
      BuildContext context) async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) {
      return (
        const <ChildStreak>[],
        const <String, Child>{},
        const <String, int>{}
      );
    }
    return (
      const ReportRepository().streaks(
        yearId: yearId,
        classId: classId,
        minAbsent: 999,
        minPresent: 3,
      ),
      const ChildRepository()
          .byClass(classId)
          .then((list) => {for (final c in list) c.id: c})
          .catchError((Object _) => const <String, Child>{}),
      pointsOfClass(yearId, classId),
    ).wait;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${AppStrings.championsTitle} • $className'),
      ),
      body: SafeArea(
        child: AsyncSection<
            (List<ChildStreak>, Map<String, Child>, Map<String, int>)>(
          load: load ?? () => _load(context),
          loading: const SkeletonList(),
          builder: (context, data, reload) => ChampionsView(
            streaks: data.$1,
            children: data.$2,
            points: data.$3,
          ),
        ),
      ),
    );
  }
}

/// The children on a run of Saturdays, longest first, each with the tier the
/// run has reached and what is left for the next one.
@visibleForTesting
class ChampionsView extends StatelessWidget {
  const ChampionsView({
    super.key,
    required this.streaks,
    this.children = const {},
    this.points = const {},
    this.showClass = false,
  });

  final List<ChildStreak> streaks;
  final Map<String, Child> children;

  /// childId -> game points: breaks ties between equal runs and is shown.
  final Map<String, int> points;

  /// Name the class on every line (a list over several classes).
  final bool showClass;

  @override
  Widget build(BuildContext context) {
    final entries =
        ClassChampionsCard.championsOf(streaks, points: points);
    if (entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 40),
          EmptyState(
            icon: Icons.local_fire_department_outlined,
            title: AppStrings.noCommittedYet,
            body: AppStrings.committedStreakHint,
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChampionLine(
              rank: i + 1,
              streak: entries[i],
              child: children[entries[i].childId],
              points: points[entries[i].childId],
              showClass: showClass,
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          AppStrings.committedStreakHint,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _ChampionLine extends StatelessWidget {
  const _ChampionLine({
    required this.rank,
    required this.streak,
    this.child,
    this.points,
    this.showClass = false,
  });

  final int rank;
  final int? points;
  final ChildStreak streak;
  final Child? child;
  final bool showClass;

  @override
  Widget build(BuildContext context) {
    final goal = ChampionTier.nextGoal(streak.presentStreak);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Initial(name: streak.childName, child: child, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showClass && streak.className.isNotEmpty
                      ? '${streak.childName}  •  ${streak.className}'
                      : streak.childName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _TierPill(run: streak.presentStreak),
                    if (goal != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          goal,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RunBadge(run: streak.presentStreak),
              if (points != null)
                Text(
                  AppStrings.pointsOf(points!),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Each child's game points in a class: childId -> points. A hint, empty
/// when it cannot be read.
Future<Map<String, int>> pointsOfClass(String yearId, String classId) async {
  try {
    final rows = await const BadgeRepository()
        .leaderboard(yearId: yearId, classId: classId);
    return {for (final r in rows) r.childId: r.gamePoints};
  } catch (_) {
    return const <String, int>{};
  }
}

class _TierPill extends StatelessWidget {
  const _TierPill({required this.run});

  final int run;

  @override
  Widget build(BuildContext context) {
    final (tier, color) = ChampionTier.of(run);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tier,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.readable(color),
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.size, this.child});

  final String name;
  final double size;

  /// The child, when known: their photo replaces the initial.
  final Child? child;

  @override
  Widget build(BuildContext context) {
    final c = child;
    if (c != null && c.hasPhoto) {
      return ChildAvatar(child: c, size: size);
    }
    final t = name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.navyTint,
      ),
      child: Text(
        t.isEmpty ? '؟' : String.fromCharCode(t.runes.first),
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: AppColors.navy,
        ),
      ),
    );
  }
}
