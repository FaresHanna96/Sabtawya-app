import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/badges.dart';
import '../../data/repositories/badge_repository.dart';
import '../../state/session_controller.dart';

/// ترتيب الفصل: the class by this year's points, opened from the rank on a
/// child's points card. A plain list with the opened child marked; the
/// points and levels stay on the child's page.
class ClassOrderScreen extends StatelessWidget {
  const ClassOrderScreen({
    super.key,
    required this.classId,
    required this.className,
    this.highlightChildId,
    this.load,
  });

  final String classId;
  final String className;

  /// The child the screen was opened from, marked in the list.
  final String? highlightChildId;

  /// Replaces the real read; tests give their own.
  final Future<List<LeaderboardRow>> Function()? load;

  Future<List<LeaderboardRow>> _load(BuildContext context) async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return const <LeaderboardRow>[];
    return const BadgeRepository().leaderboard(yearId: yearId, classId: classId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.classRankingOf(className))),
      body: SafeArea(
        child: AsyncSection<List<LeaderboardRow>>(
          load: load ?? () => _load(context),
          builder: (context, rows, reload) {
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
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _OrderLine(
                      rank: LeaderboardRow.rankOf(rows, row.childId) ?? 0,
                      row: row,
                      highlight: row.childId == highlightChildId,
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
          },
        ),
      ),
    );
  }
}

class _OrderLine extends StatelessWidget {
  const _OrderLine({
    required this.rank,
    required this.row,
    required this.highlight,
  });

  final int rank;
  final LeaderboardRow row;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: rank <= 3 ? AppColors.goldText : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.childName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            AppStrings.badgesCount(row.badgesEarned),
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Text(
            '${row.gamePoints}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}
