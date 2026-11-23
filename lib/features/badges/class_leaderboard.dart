import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/badges.dart';
import '../../data/repositories/badge_repository.dart';
import '../../state/session_controller.dart';

const _medals = [Color(0xFFF2C46D), Color(0xFFD7DCE5), Color(0xFFE0A77A)];

/// ترتيب الفصل: the podium for the first three, then everyone else; this
/// month's points or the whole year's.
class ClassLeaderboardScreen extends StatefulWidget {
  const ClassLeaderboardScreen({
    super.key,
    required this.classId,
    required this.className,
    this.highlightChildId,
  });

  final String classId;
  final String className;

  /// The child the screen was opened from, marked in the list.
  final String? highlightChildId;

  @override
  State<ClassLeaderboardScreen> createState() => _ClassLeaderboardScreenState();
}

class _ClassLeaderboardScreenState extends State<ClassLeaderboardScreen> {
  static const _repo = BadgeRepository();
  bool _month = true;

  Future<List<LeaderboardRow>> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return const [];
    final now = DateTime.now();
    return _repo.leaderboard(
      yearId: yearId,
      classId: widget.classId,
      from: _month ? DateTime(now.year, now.month) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.classRankingOf(widget.className))),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.navy,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: RangeToggle(
                month: _month,
                onChanged: (m) {
                  Haptics.select();
                  setState(() => _month = m);
                },
              ),
            ),
            Expanded(
              child: AsyncSection<List<LeaderboardRow>>(
                key: ValueKey(_month),
                load: _load,
                builder: (context, rows, reload) => LeaderboardView(
                  rows: rows,
                  highlightChildId: widget.highlightChildId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «الشهر ده / السنة دي» on the navy strip.
@visibleForTesting
class RangeToggle extends StatelessWidget {
  const RangeToggle({super.key, required this.month, required this.onChanged});

  final bool month;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool isMonth) {
      final on = month == isMonth;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: Material(
            color: on ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(isMonth),
              child: SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: on ? AppColors.navy : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          option(AppStrings.rankingThisMonth, true),
          const SizedBox(width: 4),
          option(AppStrings.rankingThisYear, false),
        ],
      ),
    );
  }
}

/// The ranking itself: podium, then the rest, the opened child marked.
@visibleForTesting
class LeaderboardView extends StatelessWidget {
  const LeaderboardView({super.key, required this.rows, this.highlightChildId});

  final List<LeaderboardRow> rows;
  final String? highlightChildId;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty || rows.first.gamePoints == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 40),
          EmptyState(
            icon: Icons.emoji_events_outlined,
            title: AppStrings.noRankingYet,
          ),
        ],
      );
    }
    final top = rows.take(3).toList();
    final rest = rows.skip(3).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _Podium(rows: top),
        const SizedBox(height: 16),
        for (var i = 0; i < rest.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RankLine(
              rank: LeaderboardRow.rankOf(rows, rest[i].childId) ?? i + 4,
              row: rest[i],
              highlight: rest[i].childId == highlightChildId,
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          AppStrings.rankingPointsNote,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.rows});

  final List<LeaderboardRow> rows;

  @override
  Widget build(BuildContext context) {
    // Second, first, third: the winner in the middle.
    final order = [
      if (rows.length > 1) (rows[1], 2),
      (rows[0], 1),
      if (rows.length > 2) (rows[2], 3),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (row, place) in order)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  _Initial(
                    name: row.childName,
                    size: place == 1 ? 62 : 50,
                    ring: _medals[place - 1],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    row.childName,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: place == 1 ? 76 : (place == 2 ? 58 : 46),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: _medals[place - 1],
                          child: Text(
                            '$place',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${row.gamePoints}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.size, this.ring});

  final String name;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final t = name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.navyTint,
        border: ring == null ? null : Border.all(color: ring!, width: 3),
      ),
      child: Text(
        t.isEmpty ? '؟' : String.fromCharCode(t.runes.first),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: AppColors.navy,
        ),
      ),
    );
  }
}

class _RankLine extends StatelessWidget {
  const _RankLine({
    required this.rank,
    required this.row,
    this.highlight = false,
  });

  final int rank;
  final LeaderboardRow row;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? AppColors.navyTint : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AppColors.navy
              : AppColors.navy.withValues(alpha: 0.08),
          width: highlight ? 2 : 1,
        ),
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
          _Initial(name: row.childName, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.childName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  AppStrings.badgesCount(row.badgesEarned),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            '${row.gamePoints}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

/// ترتيب الفصل on the class page: the first three, and «عرض الكل».
class ClassRankingCard extends StatelessWidget {
  const ClassRankingCard(
      {super.key, required this.top, required this.onSeeAll});

  /// The best three (or fewer), best first.
  final List<LeaderboardRow> top;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: AppStrings.classRankingTitle,
      icon: Icons.emoji_events_rounded,
      accent: AppColors.gold,
      trailing: TextButton(
        onPressed: onSeeAll,
        child: const Text(AppStrings.seeAll),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: top.isEmpty
          ? const Text(
              AppStrings.noRankingYet,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            )
          : Column(
              children: [
                for (var i = 0; i < top.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: _medals[i],
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            top[i].childName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${top[i].gamePoints}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
