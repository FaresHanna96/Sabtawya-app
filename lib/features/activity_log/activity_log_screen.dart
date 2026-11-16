import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/arabic_sort.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/child.dart';
import '../../data/models/profile.dart';
import '../../data/models/reports.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/servant_repository.dart';

/// سجل النشاط: everything the app recorded about who did what, newest first,
/// 50 at a time, which an admin can narrow by servant, kind of record, child
/// and period. Admins only (the database refuses everyone else).
class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

/// The periods offered; null means no limit.
enum LogPeriod {
  all(AppStrings.logPeriodAll, null),
  today(AppStrings.logPeriodToday, 0),
  week(AppStrings.logPeriodWeek, 6),
  month(AppStrings.logPeriodMonth, 29);

  const LogPeriod(this.label, this.daysBack);
  final String label;
  final int? daysBack;
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  static const _pageSize = 50;
  static const _repository = ReportRepository();

  /// The record kinds the log holds, in the order they are offered.
  static const _entities = <(String?, String)>[
    (null, AppStrings.logEntityAll),
    ('attendance_records', AppStrings.logEntityAttendance),
    ('children', AppStrings.logEntityChildren),
    ('class_servants', AppStrings.logEntityAssignments),
    ('profiles', AppStrings.logEntityAccounts),
  ];

  final _entries = <ActivityLogEntry>[];
  List<Profile> _servants = const <Profile>[];
  List<Child> _children = const <Child>[];

  String? _actorId;
  String? _entity;
  Child? _child;
  LogPeriod _period = LogPeriod.all;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  /// Bumped on every new search, so an answer to an old one is ignored.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _search();
    _loadPeople();
  }

  /// The servants and children behind the two pickers; the log works without.
  Future<void> _loadPeople() async {
    try {
      final (servants, children) = await (
        const ServantRepository().servants(),
        const ChildRepository().all(includeInactive: true),
      ).wait;
      if (!mounted) return;
      setState(() {
        _servants = servants;
        _children = children;
      });
    } catch (_) {}
  }

  DateTime? get _from {
    final days = _period.daysBack;
    if (days == null) return null;
    final today = AppDateUtils.dateOnly(DateTime.now());
    return today.subtract(Duration(days: days));
  }

  Future<void> _search() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _entries.clear();
      _hasMore = false;
    });
    try {
      final page = await _fetch(0);
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries.addAll(page);
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _more() async {
    if (_loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await _fetch(_entries.length);
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries.addAll(page);
        _hasMore = page.length == _pageSize;
      });
    } catch (_) {
      // The rows already shown stay; the button is still there to retry.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<List<ActivityLogEntry>> _fetch(int offset) => _repository.activityPage(
        offset: offset,
        limit: _pageSize,
        actorId: _actorId,
        entity: _entity,
        childId: _child?.id,
        from: _from,
      );

  bool get _filtered =>
      _actorId != null ||
      _entity != null ||
      _child != null ||
      _period != LogPeriod.all;

  void _clear() {
    setState(() {
      _actorId = null;
      _entity = null;
      _child = null;
      _period = LogPeriod.all;
    });
    _search();
  }

  Future<void> _pickChild() async {
    final picked = await showModalBottomSheet<Child>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChildPickerSheet(children: _children),
    );
    if (picked == null || !mounted) return;
    setState(() => _child = picked);
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.activityLogTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _search,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _filters(),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                EmptyState(
                  title: AppStrings.loadFailed,
                  body: _error,
                  icon: Icons.error_outline_rounded,
                  action: FilledButton(
                    onPressed: _search,
                    child: const Text(AppStrings.retry),
                  ),
                )
              else if (_entries.isEmpty)
                const EmptyState(
                  title: AppStrings.logEmpty,
                  icon: Icons.history_rounded,
                )
              else ...[
                for (final e in _entries) _EntryTile(entry: e),
                if (_hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: _loadingMore ? null : _more,
                      child: _loadingMore
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(AppStrings.logLoadMore),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters() {
    return SectionCard(
      title: AppStrings.logFilters,
      icon: Icons.filter_list_rounded,
      accent: AppColors.sky,
      collapsible: true,
      initiallyExpanded: true,
      trailing: _filtered
          ? TextButton(
              onPressed: _clear, child: const Text(AppStrings.logClear))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _actorId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: AppStrings.logByServant,
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(AppStrings.logAnyServant),
              ),
              for (final s in _servants)
                DropdownMenuItem<String?>(value: s.id, child: Text(s.fullName)),
            ],
            onChanged: (v) {
              setState(() => _actorId = v);
              _search();
            },
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickChild,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: AppStrings.logByChild,
                prefixIcon: const Icon(Icons.child_care_outlined),
                suffixIcon: _child == null
                    ? const Icon(Icons.search_rounded)
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          setState(() => _child = null);
                          _search();
                        },
                      ),
              ),
              child: Text(_child?.fullName ?? AppStrings.logAnyChild),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (value, label) in _entities)
                ChoiceChip(
                  label: Text(label),
                  selected: _entity == value,
                  onSelected: (_) {
                    setState(() => _entity = value);
                    _search();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final p in LogPeriod.values)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _period == p,
                  onSelected: (_) {
                    setState(() => _period = p);
                    _search();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final ActivityLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (entry.entity) {
      'attendance_records' => (Icons.fact_check_rounded, AppColors.success),
      'children' => (Icons.child_care_rounded, AppColors.navy),
      'class_servants' => (Icons.group_add_rounded, AppColors.olive),
      'profiles' => (Icons.person_add_alt_1_rounded, AppColors.sky),
      _ => (Icons.history_rounded, AppColors.muted),
    };
    final extra = entry.extra;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.description,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  if (extra != null) ...[
                    const SizedBox(height: 2),
                    Text(extra,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    AppDateUtils.formatDateTime(entry.createdAt.toLocal()),
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A search over the children by name.
@visibleForTesting
class ChildPickerSheet extends StatefulWidget {
  const ChildPickerSheet({super.key, required this.children});

  final List<Child> children;

  @override
  State<ChildPickerSheet> createState() => _ChildPickerSheetState();
}

class _ChildPickerSheetState extends State<ChildPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = ArabicSort.key(_query);
    final shown = [
      for (final c in widget.children)
        if (q.isEmpty || ArabicSort.key(c.fullName).contains(q)) c,
    ]..sort((a, b) => ArabicSort.compare(a.fullName, b.fullName));

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: AppStrings.logSearchChild,
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const Center(child: Text(AppStrings.noResults))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, i) => ListTile(
                        title: Text(shown[i].fullName),
                        onTap: () => Navigator.of(context).pop(shown[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
