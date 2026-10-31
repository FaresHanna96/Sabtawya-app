import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
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

class _CompetitionsScreenState extends State<CompetitionsScreen> {
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
  Widget build(BuildContext context) {
    final isAdmin = context.watch<SessionController>().isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.competitions)),
      body: SafeArea(
        child: AsyncSection<List<Competition>>(
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
                return _CompetitionTile(
                  competition: c,
                  isAdmin: isAdmin,
                  onTap: () => _openDetail(c),
                  onEdit: () => _edit(c),
                  onDelete: () => _delete(c),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.addCompetition),
            )
          : null,
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
