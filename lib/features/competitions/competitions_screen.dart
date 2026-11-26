import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/pill_tabs.dart';
import '../../core/widgets/date_cube.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/competition.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/competition_repository.dart';
import '../../data/services/excel_service.dart';
import '../../data/services/file_service.dart';
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

  static const _repository = CompetitionRepository();
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final all = await _repository.listCompetitions();
      if (!mounted) return;
      if (all.isEmpty) {
        Ui.info(context, AppStrings.noCompetitions);
        return;
      }
      final picked = await showModalBottomSheet<List<Competition>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _ExportPickerSheet(competitions: all),
      );
      if (picked == null || picked.isEmpty || !mounted) return;

      final session = context.read<SessionController>();
      final names = {
        for (final c in session.myClasses) c.classId: c.className,
      };
      final children = await const ChildRepository().all(includeInactive: true);
      final marks = await _repository.marksFor([for (final c in picked) c.id]);
      final bytes = ExcelService.competitionsWorkbook(
        competitions: picked,
        children: children,
        marks: marks,
        classNameOf: (id) => names[id] ?? AppStrings.unknown,
      );
      await FileService.saveAndShare(
        fileName: FileService.xlsxName(AppStrings.exportCompetitions),
        bytes: bytes,
        shareText: AppStrings.exportCompetitions,
      );
      if (mounted) Ui.success(context, AppStrings.exportDone);
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    // أمين الخدمة and خادم عام add and edit competitions; only the admin deletes.
    final canManage = session.isAdmin || session.isGeneralServant;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.competitions),
        actions: [
          IconButton(
            tooltip: AppStrings.exportCompetitions,
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
          ),
        ],
        bottom: pillTabs(
          controller: _tabs,
          onDark: true,
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
            _ListTab(canManage: canManage, canDelete: session.isAdmin),
            const _ScoresTab(),
          ],
        ),
      ),
    );
  }
}

class _ExportPickerSheet extends StatefulWidget {
  const _ExportPickerSheet({required this.competitions});

  final List<Competition> competitions;

  @override
  State<_ExportPickerSheet> createState() => _ExportPickerSheetState();
}

class _ExportPickerSheetState extends State<_ExportPickerSheet> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final all = widget.competitions;
    final allSelected = _selected.length == all.length;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.exportCompetitionsHint,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      if (allSelected) {
                        _selected.clear();
                      } else {
                        _selected.addAll(all.map((c) => c.id));
                      }
                    }),
                    child: Text(allSelected
                        ? AppStrings.clearSelection
                        : AppStrings.selectAll),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: all.length,
                itemBuilder: (context, i) {
                  final c = all[i];
                  return CheckboxListTile(
                    value: _selected.contains(c.id),
                    onChanged: (v) => setState(() {
                      v == true ? _selected.add(c.id) : _selected.remove(c.id);
                    }),
                    title: Text(c.title),
                    subtitle: Text(
                        '${AppDateUtils.formatDate(c.weekDate)}  •  / ${c.maxMark}'),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                            all.where((c) => _selected.contains(c.id)).toList(),
                          ),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(
                      '${AppStrings.exportSelected} (${_selected.length})'),
                ),
              ),
            ),
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
  const _ListTab({required this.canManage, required this.canDelete});

  final bool canManage;
  final bool canDelete;

  @override
  State<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<_ListTab> with AutomaticKeepAliveClientMixin {
  static const _repository = CompetitionRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<Competition>>>();

  /// Whether there is at least one competition: the add button then floats
  /// over the list (with none, the empty page has its own).
  bool _hasAny = false;

  Future<List<Competition>> _load() async {
    final list = await _repository.listCompetitions();
    if (mounted && _hasAny != list.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hasAny = list.isNotEmpty);
      });
    }
    return list;
  }
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
          loading: const SkeletonList(),
          key: _sectionKey,
          load: _load,
          builder: (context, competitions, reload) {
            if (competitions.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: AppStrings.noCompetitions,
                    body: widget.canManage
                        ? AppStrings.noCompetitionsBody
                        : AppStrings.noCompetitionsViewer,
                    action: widget.canManage
                        ? FilledButton.icon(
                            onPressed: _add,
                            icon: const Icon(Icons.add),
                            label: const Text(AppStrings.addCompetition),
                          )
                        : null,
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
                    canManage: widget.canManage,
                    canDelete: widget.canDelete,
                    onTap: () => _openDetail(c),
                    onEdit: () => _edit(c),
                    onDelete: () => _delete(c),
                  ),
                );
              },
            );
          },
        ),
        if (widget.canManage && _hasAny)
          PositionedDirectional(
            bottom: 24,
            end: 16,
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
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 60),
              EmptyState(
                icon: Icons.leaderboard_outlined,
                title: AppStrings.noScoresYet,
                body: AppStrings.noScoresYetBody,
              ),
            ],
          );
        }

        final best = scores.first.totalMarks;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: scores.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => FadeSlideIn(
            index: index,
            child: _ScoreRow(
              score: scores[index],
              rank: index + 1,
              share: best <= 0 ? 0 : scores[index].totalMarks / best,
            ),
          ),
        );
      },
    );
  }
}

/// One child in the cumulative ranking: a medal for the first three, the
/// name, a bar against the leader, and the total with how many competitions.
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.score,
    required this.rank,
    required this.share,
  });

  final ChildCompetitionScore score;
  final int rank;

  /// 0-1: this child's total against the first place.
  final double share;

  static const _silver = Color(0xFF8A94A6);
  static const _bronze = Color(0xFFB0703A);

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => AppColors.gold,
      2 => _silver,
      3 => _bronze,
      _ => null,
    };
    final bar = medal ?? AppColors.navyLight;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (medal ?? AppColors.muted).withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: medal == null
                  ? Text(
                      '$rank',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted,
                      ),
                    )
                  : Icon(Icons.emoji_events_rounded, color: medal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    score.childName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: share.clamp(0.0, 1.0),
                      minHeight: 5,
                      color: bar,
                      backgroundColor: bar.withValues(alpha: 0.12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppStrings.avgMark}: ${score.avgMark.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${score.totalMarks}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  AppStrings.competitionsCountLabel(score.competitionsCount),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompetitionTile extends StatelessWidget {
  const _CompetitionTile({
    required this.competition,
    required this.canManage,
    required this.canDelete,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Competition competition;
  final bool canManage;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// «النهارده» / «جاية» for a competition not yet past; null once it is.
  String? get _status {
    final today = AppDateUtils.dateOnly(DateTime.now());
    final day = AppDateUtils.dateOnly(competition.weekDate);
    if (day.isAtSameMomentAs(today)) return AppStrings.competitionToday;
    if (day.isAfter(today)) return AppStrings.competitionUpcoming;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final statusColor = status == null ? AppColors.navy : AppColors.olive;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              DateCube(date: competition.weekDate, color: statusColor),
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
                      [
                        AppDateUtils.weekdayName(competition.weekDate),
                        if (status != null) status,
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 13,
                        color: status == null
                            ? AppColors.muted
                            : AppColors.readable(statusColor),
                        fontWeight:
                            status == null ? FontWeight.w400 : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.olive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '/ ${competition.maxMark}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.oliveText,
                  ),
                ),
              ),
              if (canManage) ...[
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
                    if (canDelete)
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
