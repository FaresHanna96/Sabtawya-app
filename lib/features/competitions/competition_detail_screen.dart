import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/class_filter_chips.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/competition.dart';
import '../../data/repositories/competition_repository.dart';
import '../../state/session_controller.dart';

class CompetitionDetailScreen extends StatelessWidget {
  const CompetitionDetailScreen({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(competition.title)),
      body: SafeArea(child: _MarksTab(competition: competition)),
    );
  }
}

// ---------------------------------------------------------------------------
// Marks entry for a single competition
// ---------------------------------------------------------------------------

class _MarksTab extends StatefulWidget {
  const _MarksTab({required this.competition});

  final Competition competition;

  @override
  State<_MarksTab> createState() => _MarksTabState();
}

class _MarksTabState extends State<_MarksTab> {
  static const _repository = CompetitionRepository();

  final _sectionKey =
      GlobalKey<AsyncSectionState<List<Map<String, dynamic>>>>();

  // childId -> controller
  final _controllers = <String, TextEditingController>{};

  String _query = '';
  String? _classId;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _repository.childrenWithMarks(widget.competition.id);
    for (final row in rows) {
      final id = row['id'] as String;
      final mark = row['mark'];
      if (!_controllers.containsKey(id)) {
        _controllers[id] = TextEditingController(
          text: mark != null ? '$mark' : '',
        );
      } else {
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

        // Group by class, after the search and class filters. Hidden rows keep
        // their typed marks: they live in the controllers, and save covers all.
        final allClassIds = <String>[];
        for (final row in rows) {
          final id = row['class_id'] as String? ?? '';
          if (!allClassIds.contains(id)) allClassIds.add(id);
        }
        final query = _query.trim();
        final byClass = <String, List<Map<String, dynamic>>>{};
        for (final row in rows) {
          final classId = row['class_id'] as String? ?? '';
          if (_classId != null && classId != _classId) continue;
          if (query.isNotEmpty &&
              !(row['full_name']?.toString() ?? '').contains(query)) {
            continue;
          }
          (byClass[classId] ??= []).add(row);
        }

        final session = context.read<SessionController>();
        String className(String id) {
          for (final c in session.myClasses) {
            if (c.classId == id) return c.className;
          }
          return id;
        }

        var rowIndex = 0;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: AppStrings.search,
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            // Classes as the year x boys/girls grid (no sideways scrolling).
            if (allClassIds.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ClassFilterChips(
                  classes: [
                    for (final id in allClassIds)
                      ClassFilterOption(id: id, name: className(id)),
                  ],
                  selectedId: _classId,
                  onSelected: (id) => setState(() => _classId = id),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  if (byClass.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text(
                          AppStrings.noResults,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ),
                  for (final entry in byClass.entries.toList()
                    ..sort((a, b) =>
                        className(a.key).compareTo(className(b.key)))) ...[
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
                    ...entry.value.map((row) => staggered(
                          rowIndex++,
                          _MarkRow(
                            row: row,
                            maxMark: widget.competition.maxMark,
                            controller: _controllers[row['id'] as String]!,
                          ),
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
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                hintText: '— / $maxMark',
                hintStyle:
                    const TextStyle(fontSize: 12, color: AppColors.muted),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
