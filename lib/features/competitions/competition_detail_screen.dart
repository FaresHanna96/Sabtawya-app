import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/competition.dart';
import '../../data/repositories/competition_repository.dart';
import '../../state/session_controller.dart';

class CompetitionDetailScreen extends StatefulWidget {
  const CompetitionDetailScreen({super.key, required this.competition});

  final Competition competition;

  @override
  State<CompetitionDetailScreen> createState() =>
      _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.competition.title),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: AppStrings.markChildren),
            Tab(text: AppStrings.cumulativeScores),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: [
            _MarksTab(competition: widget.competition),
            _ScoresTab(competition: widget.competition),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1 — تسجيل العلامات
// ---------------------------------------------------------------------------

class _MarksTab extends StatefulWidget {
  const _MarksTab({required this.competition});

  final Competition competition;

  @override
  State<_MarksTab> createState() => _MarksTabState();
}

class _MarksTabState extends State<_MarksTab>
    with AutomaticKeepAliveClientMixin {
  static const _repository = CompetitionRepository();

  final _sectionKey =
      GlobalKey<AsyncSectionState<List<Map<String, dynamic>>>>();

  // childId -> controller
  final _controllers = <String, TextEditingController>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows =
        await _repository.childrenWithMarks(widget.competition.id);
    // Sync controllers
    for (final row in rows) {
      final id = row['id'] as String;
      final mark = row['mark'];
      if (!_controllers.containsKey(id)) {
        _controllers[id] = TextEditingController(
          text: mark != null ? '$mark' : '',
        );
      } else {
        // Update existing only if text differs (avoid cursor jump)
        final text = mark != null ? '$mark' : '';
        if (_controllers[id]!.text != text) {
          _controllers[id]!.text = text;
        }
      }
    }
    return rows;
  }

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _saveAll(List<Map<String, dynamic>> rows) async {
    FocusScope.of(context).unfocus();

    final updates = <String, int>{};
    final deletes = <String>[];

    for (final row in rows) {
      final id = row['id'] as String;
      final text = _controllers[id]?.text.trim() ?? '';
      if (text.isEmpty) {
        if (row['mark_id'] != null) deletes.add(id);
      } else {
        final val = int.tryParse(text);
        if (val != null) {
          if (val > widget.competition.maxMark) {
            Ui.error(
              context,
              Exception(
                '${row['full_name']}: ${AppStrings.competitionMaxMark} ${widget.competition.maxMark}',
              ),
            );
            return;
          }
          updates[id] = val;
        }
      }
    }

    final saved = await Ui.runGuarded(
      context,
      () async {
        for (final entry in updates.entries) {
          await _repository.upsertMark(
              widget.competition.id, entry.key, entry.value);
        }
        for (final childId in deletes) {
          await _repository.deleteMark(widget.competition.id, childId);
        }
      },
      successMessage: AppStrings.markSaved,
    );

    if (saved && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AsyncSection<List<Map<String, dynamic>>>(
      key: _sectionKey,
      load: _load,
      builder: (context, rows, reload) {
        if (rows.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: Icons.groups_outlined,
              title: AppStrings.noChildren,
              body: AppStrings.noChildrenBody,
            ),
          );
        }

        // Group by class
        final byClass = <String, List<Map<String, dynamic>>>{};
        for (final row in rows) {
          final classId = row['class_id'] as String? ?? '';
          (byClass[classId] ??= []).add(row);
        }

        final session = context.read<SessionController>();
        String className(String id) {
          for (final c in session.myClasses) {
            if (c.classId == id) return c.className;
          }
          return id;
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  for (final entry in byClass.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text(
                        className(entry.key),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    ...entry.value.map((row) => _MarkRow(
                          row: row,
                          maxMark: widget.competition.maxMark,
                          controller: _controllers[row['id'] as String]!,
                        )),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.icon(
                onPressed: () => _saveAll(rows),
                icon: const Icon(Icons.save_outlined),
                label: const Text(AppStrings.save),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.row,
    required this.maxMark,
    required this.controller,
  });

  final Map<String, dynamic> row;
  final int maxMark;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row['full_name'] as String? ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 10),
                hintText: '— / $maxMark',
                hintStyle: const TextStyle(
                    fontSize: 12, color: AppColors.muted),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2 — المجموع التراكمي
// ---------------------------------------------------------------------------

class _ScoresTab extends StatelessWidget {
  const _ScoresTab({required this.competition});

  final Competition competition;

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
