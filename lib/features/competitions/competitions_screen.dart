import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/competition.dart';
import '../../data/repositories/competition_repository.dart';
import '../../state/session_controller.dart';
import 'competition_detail_screen.dart';
import 'competition_form_screen.dart';

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<SessionController>().isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.competitions),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: AppStrings.competitionsList),
            Tab(text: AppStrings.cumulativeScores),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: [
            _ListTab(isAdmin: isAdmin),
            const _ScoresTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1 — list of competitions
// ---------------------------------------------------------------------------

class _ListTab extends StatefulWidget {
  const _ListTab({required this.isAdmin});

  final bool isAdmin;

  @override
  State<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<_ListTab>
    with AutomaticKeepAliveClientMixin {
  static const _repository = CompetitionRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<Competition>>>();

  Future<List<Competition>> _load() => _repository.listCompetitions();
  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _add() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const CompetitionFormScreen(),
      ),
    );
    if (added == true) await _reload();
  }

  Future<void> _edit(Competition competition) async {
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CompetitionFormScreen(competition: competition),
      ),
    );
    if (edited == true) await _reload();
  }

  Future<void> _delete(Competition competition) async {
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.deleteCompetition,
      message: AppStrings.confirmDeleteCompetition,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await Ui.runGuarded(
      context,
      () => _repository.deleteCompetition(competition.id),
    );
    if (mounted) await _reload();
  }

  Future<void> _openDetail(Competition competition) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CompetitionDetailScreen(competition: competition),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Stack(
      children: [
        AsyncSection<List<Competition>>(
          key: _sectionKey,
          load: _load,
          builder: (context, competitions, reload) {
            if (competitions.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: AppStrings.noCompetitions,
                    body: AppStrings.noCompetitionsBody,
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: competitions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final c = competitions[index];
                return FadeSlideIn(
                  index: index,
                  child: _CompetitionTile(
                    competition: c,
                    isAdmin: widget.isAdmin,
                    onTap: () => _openDetail(c),
                    onEdit: () => _edit(c),
                    onDelete: () => _delete(c),
                  ),
                );
              },
            );
          },
        ),
        if (widget.isAdmin)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.addCompetition),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2 — cumulative scores across ALL competitions
// ---------------------------------------------------------------------------

class _ScoresTab extends StatelessWidget {
  const _ScoresTab();

  static const _repository = CompetitionRepository();

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<ChildCompetitionScore>>(
      load: () => _repository.cumulativeScores(),
      builder: (context, scores, reload) {
        if (scores.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: Icons.leaderboard_outlined,
              title: AppStrings.noCompetitions,
              body: AppStrings.noCompetitionsBody,
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: scores.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final score = scores[index];
            final rank = index + 1;
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: rank <= 3
                              ? AppColors.warning
                              : AppColors.muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            score.childName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${AppStrings.avgMark}: ${score.avgMark}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${score.totalMarks}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          '${score.competitionsCount} ${AppStrings.weeklyCompetition}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CompetitionTile extends StatelessWidget {
  const _CompetitionTile({
    required this.competition,
    required this.isAdmin,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Competition competition;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.navy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      competition.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppDateUtils.formatDate(competition.weekDate),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.olive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '/ ${competition.maxMark}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.olive,
                  ),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 4),
                PopupMenuButton<_Action>(
                  onSelected: (action) {
                    if (action == _Action.edit) onEdit();
                    if (action == _Action.delete) onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _Action.edit,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text(AppStrings.editCompetition),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: _Action.delete,
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                        title: Text(
                          AppStrings.deleteCompetition,
                          style: TextStyle(color: AppColors.danger),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _Action { edit, delete }
